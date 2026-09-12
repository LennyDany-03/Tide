-- =============================================================================
-- Tide · Supabase billing setup  (Razorpay)
--
-- Run after auth_setup.sql and habits_setup.sql:
--   Supabase → SQL Editor → New query → Run.
-- Safe to run again: every statement replaces or skips what already exists.
--
-- What it creates
--   1. public.billing_plans     the price list — the server's copy, and the
--                               only one an order is ever priced from
--   2. public.payment_orders    one row per Razorpay order, its whole life
--   3. public.subscriptions     one row per account: which plan, until when
--   4. public.billing_events    the webhook ledger, so a replayed event is a
--                               no-op rather than a second month
--   5. row level security       read-only for the account; every write comes
--                               from an Edge Function holding the service role
--   6. entitlement()            what the app asks: am I Pro, until when
--      billing_snapshot()       that, plus the receipts, in one request
--   7. apply_payment()          the one place a period is granted or extended
--      revoke_payment()         and the one place it is taken back
--   8. realtime broadcasts      a changed subscription announced on the
--                               owner's private topic, billing:<user id>
--   9. expire_subscriptions()   optional tidying for a cron
--
-- The shape of the flow (see supabase/functions/)
--
--   app  ──▶ razorpay-create-order ──▶ Razorpay POST /v1/orders
--                    │
--                    ├── payment_orders row, status 'created'
--                    ▼
--   app  ──▶ Razorpay checkout — the money moves
--                    │
--                    ├──▶ razorpay-verify-payment ─┐  both land on
--                    └──▶ razorpay-webhook ────────┴─▶ apply_payment()
--                                                          │
--                                              subscriptions row extended
--                                                          │
--                                          broadcast on billing:<user id>
--                                                          │
--                                                   the app turns Pro
--
-- Two things this file is built around, and neither is negotiable:
--
--   **The client never states a price.** It names a plan id. The amount is
--   read from billing_plans inside the Edge Function, so a tampered request
--   can buy a year for one rupee only by editing this table.
--
--   **The client never writes entitlement.** `authenticated` has SELECT on
--   these tables and nothing else — no INSERT, no UPDATE, no RPC that grants.
--   Every write arrives through the service role inside an Edge Function,
--   after a signature has been checked. A stolen session token cannot make
--   itself Pro; the most it can do is read its own receipts.
-- =============================================================================


-- 1. Plans ----------------------------------------------------------------------
-- The price list. Amounts are in the currency's smallest unit — paise — which
-- is what Razorpay takes, and what keeps money out of a float.
--
-- `period_days` is what one payment buys. Calendar months are deliberately not
-- used: 30 and 365 days are the same length for everybody, so a period can be
-- extended with plain date arithmetic and two people who paid on the same day
-- always lose access on the same day.

create table if not exists public.billing_plans (
  id           text primary key check (id ~ '^[a-z0-9_]{3,40}$'),
  -- What receipts and the dashboard call it. The paywall's own copy lives in
  -- lib/config/plan_catalog.dart.
  name         text not null,
  interval     text not null check (interval in ('month', 'year')),
  period_days  integer not null check (period_days between 1 and 3660),
  amount_minor integer not null check (amount_minor > 0),
  currency     text not null default 'INR' check (char_length(currency) = 3),
  active       boolean not null default true,
  sort         smallint not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- The two Tide Pro plans. Change a price here and in
-- `lib/config/plan_catalog.dart` together — the app quotes it and the server
-- charges it, and `test/plan_catalog_test.dart` is what catches the two
-- drifting apart.
insert into public.billing_plans
  (id, name, interval, period_days, amount_minor, currency, sort)
values
  ('pro_monthly', 'Tide Pro · monthly', 'month',  30,  19900, 'INR', 1),
  ('pro_yearly',  'Tide Pro · yearly',  'year',  365, 149900, 'INR', 2)
on conflict (id) do update
  set name         = excluded.name,
      interval     = excluded.interval,
      period_days  = excluded.period_days,
      amount_minor = excluded.amount_minor,
      currency     = excluded.currency,
      sort         = excluded.sort,
      active       = true;


-- 2. Orders ---------------------------------------------------------------------
-- One row per Razorpay order, written before the person is shown anything to
-- pay with, and updated as the payment moves through its states.
--
-- It exists for three reasons, in order of how much they matter:
--
--   1. Signature verification needs an order id that did not come from the
--      device. Razorpay's own guide is blunt about this: verify against the
--      order id from *your* database. This table is that database.
--   2. It is the receipt — Settings reads it, support reads it, a dispute
--      reads it.
--   3. It is the idempotency key. `status = 'captured'` on this row is what
--      stops the verify call and the webhook — which race, and which both
--      arrive — from buying two months with one payment.

create table if not exists public.payment_orders (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references auth.users (id) on delete cascade,
  plan_id             text not null references public.billing_plans (id),
  razorpay_order_id   text not null unique
                        check (char_length(razorpay_order_id) between 4 and 64),
  razorpay_payment_id text unique
                        check (razorpay_payment_id is null
                               or char_length(razorpay_payment_id) between 4 and 64),
  amount_minor        integer not null check (amount_minor > 0),
  currency            text not null default 'INR',
  receipt             text check (char_length(receipt) <= 40),
  status              text not null default 'created'
                        check (status in ('created', 'attempted', 'authorized',
                                          'captured', 'failed', 'refunded')),
  -- How it was paid: card, upi, netbanking, wallet. Razorpay's own word for
  -- it, kept verbatim so a method added next year never fails a constraint.
  method              text check (char_length(method) <= 32),
  -- Razorpay's error object when it failed: code, description, source, step,
  -- reason. Stored whole — the description is what the person is shown, and
  -- the other four are what make a pattern of failures readable later.
  failure             jsonb,
  notes               jsonb not null default '{}'::jsonb,
  -- When a signature was checked and found good. Null on an order nobody
  -- ever finished paying for.
  verified_at         timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index if not exists payment_orders_user_created_idx
  on public.payment_orders (user_id, created_at desc);

-- Deliberately not a unique index: somebody who abandons a UPI attempt and
-- starts a card one has two open orders, both legitimate, and only one of
-- them will ever be captured.
create index if not exists payment_orders_open_idx
  on public.payment_orders (user_id)
  where status in ('created', 'attempted', 'authorized');


-- 3. Subscriptions ----------------------------------------------------------------
-- One row per account that has ever paid. No row means free, so nothing needs
-- creating at sign-up and `entitlement()` still answers for an account that
-- has never touched this table.
--
-- These are prepaid periods, not Razorpay Subscriptions: each payment buys
-- `period_days` and nothing is auto-charged. That is a product decision with
-- a security consequence worth saying out loud — there is no mandate to
-- revoke and no card on file, and the worst case for a lapsed account is that
-- it returns to free on a date it was told about.
--
-- `status`:
--   'active'     paid, inside its period
--   'cancelled'  will not be renewed, but the paid period still runs — Pro
--                stays on until current_period_end, which is what was bought
--   'expired'    the period ran out
--   'none'       refunded or revoked; nothing is owed
--
-- Access is never read off `status` alone. `entitlement()` reads it *with*
-- current_period_end against now(), so a row nobody got round to expiring is
-- not a free year.

create table if not exists public.subscriptions (
  user_id              uuid primary key
                         references auth.users (id) on delete cascade,
  plan_id              text references public.billing_plans (id),
  status               text not null default 'none'
                         check (status in ('none', 'active', 'cancelled', 'expired')),
  source               text not null default 'razorpay'
                         check (source in ('razorpay', 'promo', 'manual')),
  current_period_start timestamptz,
  current_period_end   timestamptz,
  cancelled_at         timestamptz,
  -- The payment that last extended it, and the order that payment belongs to.
  last_payment_id      text,
  last_order_id        uuid references public.payment_orders (id) on delete set null,
  -- Every period this account has bought, newest last. A small jsonb log
  -- rather than a fourth table: it is only ever read whole, by a human, when
  -- something has gone wrong.
  history              jsonb not null default '[]'::jsonb,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  -- A paid period has both ends or neither.
  constraint subscriptions_period_complete
    check ((current_period_start is null) = (current_period_end is null)),
  constraint subscriptions_period_forward
    check (current_period_end is null
           or current_period_end > current_period_start)
);

create index if not exists subscriptions_period_end_idx
  on public.subscriptions (current_period_end)
  where status in ('active', 'cancelled');


-- 4. Webhook ledger ---------------------------------------------------------------
-- Razorpay retries a webhook it did not get a 200 from, and can deliver the
-- same event twice on its own. The primary key is the delivery's event id, so
-- a second arrival fails the insert and the handler stops there — before
-- anything has been granted.
--
-- No client role touches this table at all, not even SELECT: it holds whole
-- Razorpay payloads, which carry the payer's contact details.

create table if not exists public.billing_events (
  id          text primary key check (char_length(id) between 4 and 128),
  event       text not null,
  order_id    text,
  payment_id  text,
  payload     jsonb not null,
  handled     boolean not null default false,
  error       text,
  received_at timestamptz not null default now()
);

create index if not exists billing_events_received_idx
  on public.billing_events (received_at desc);


-- 5. Row level security and privileges -----------------------------------------------
-- The whole of the app's access to billing is three reads and two functions.
-- Everything that changes money or entitlement goes through an Edge Function
-- holding the service role — which is also the only place the Razorpay key
-- secret exists.

alter table public.billing_plans   enable row level security;
alter table public.payment_orders  enable row level security;
alter table public.subscriptions   enable row level security;
alter table public.billing_events  enable row level security;

-- The price list is public: the paywall quotes it before anyone signs in.
drop policy if exists "billing_plans_read" on public.billing_plans;
create policy "billing_plans_read"
  on public.billing_plans
  for select
  to anon, authenticated
  using (active);

drop policy if exists "payment_orders_select_own" on public.payment_orders;
create policy "payment_orders_select_own"
  on public.payment_orders
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "subscriptions_select_own" on public.subscriptions;
create policy "subscriptions_select_own"
  on public.subscriptions
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- billing_events gets no policy at all. RLS is on and nothing is permitted,
-- which is the right amount of access to a table of raw webhook bodies.

revoke all on table public.billing_plans, public.payment_orders,
                    public.subscriptions, public.billing_events
  from anon, authenticated;

grant select on table public.billing_plans to anon, authenticated;
grant select on table public.payment_orders to authenticated;
grant select on table public.subscriptions  to authenticated;


-- updated_at ------------------------------------------------------------------------
-- The same function the other two scripts install, repeated so this file does
-- not depend on the order they were run in.

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
  new.updated_at := now();
  return new;
end;
$fn$;

revoke all on function public.touch_updated_at() from public, anon, authenticated;

drop trigger if exists billing_plans_touch_updated_at on public.billing_plans;
create trigger billing_plans_touch_updated_at
  before update on public.billing_plans
  for each row execute function public.touch_updated_at();

drop trigger if exists payment_orders_touch_updated_at on public.payment_orders;
create trigger payment_orders_touch_updated_at
  before update on public.payment_orders
  for each row execute function public.touch_updated_at();

drop trigger if exists subscriptions_touch_updated_at on public.subscriptions;
create trigger subscriptions_touch_updated_at
  before update on public.subscriptions
  for each row execute function public.touch_updated_at();


-- 6. What the app asks --------------------------------------------------------------

-- The shape every caller gets back, built in one place so the Edge Functions,
-- the RPC and the realtime broadcast all describe entitlement identically.
--
-- `pro` is computed against now(), never read off `status`. That is the whole
-- point: a row saying 'active' with a period that ended last Tuesday is not
-- Pro, whatever nobody remembered to run.

create or replace function public.entitlement_of(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $fn$
  select jsonb_build_object(
    'pro', coalesce(
      s.status in ('active', 'cancelled') and s.current_period_end > now(),
      false
    ),
    'plan',                 s.plan_id,
    'interval',             p.interval,
    'status',               coalesce(s.status, 'none'),
    'source',               s.source,
    'current_period_start', s.current_period_start,
    'current_period_end',   s.current_period_end,
    'cancelled_at',         s.cancelled_at,
    'last_payment_id',      s.last_payment_id,
    -- Sent so the app can work out how long is left without trusting the
    -- device's clock, which people change.
    'server_time',          now()
  )
  from (select 1) one
  left join public.subscriptions s on s.user_id = p_user_id
  left join public.billing_plans p on p.id = s.plan_id;
$fn$;

-- Reachable only through entitlement() below, which pins the user to the JWT.
revoke all on function public.entitlement_of(uuid) from public, anon, authenticated;


-- What the app asks on sign-in, on pull to refresh, and after a payment.
create or replace function public.entitlement()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $fn$
  select public.entitlement_of((select auth.uid()));
$fn$;

revoke all on function public.entitlement() from public, anon, authenticated;
grant execute on function public.entitlement() to authenticated;


-- Entitlement plus the receipts, in one request — what Settings → Tide Pro
-- shows. Orders are capped: this is a receipt list, not an export.
create or replace function public.billing_snapshot(p_limit integer default 20)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $fn$
  select jsonb_build_object(
    'entitlement', public.entitlement(),
    'orders', coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'id',           o.id,
                 'plan',         o.plan_id,
                 'amount_minor', o.amount_minor,
                 'currency',     o.currency,
                 'status',       o.status,
                 'method',       o.method,
                 'payment_id',   o.razorpay_payment_id,
                 'created_at',   o.created_at
               )
               order by o.created_at desc
             )
        from (
          select *
            from public.payment_orders
           where user_id = (select auth.uid())
             and status in ('captured', 'refunded', 'failed')
           order by created_at desc
           limit least(greatest(coalesce(p_limit, 20), 1), 100)
        ) o
    ), '[]'::jsonb)
  );
$fn$;

revoke all on function public.billing_snapshot(integer) from public, anon, authenticated;
grant execute on function public.billing_snapshot(integer) to authenticated;


-- 7. Granting and revoking ------------------------------------------------------------

-- The one place a paid period is created or extended.
--
-- Called by razorpay-verify-payment and by razorpay-webhook — which race, and
-- which both arrive. It is safe for them to: the first caller to move the
-- order to 'captured' does the work, and every later caller gets the same
-- entitlement back without a second period being added. The order row is held
-- under `for update` for the whole transaction, so "both read 'authorized',
-- both grant" is not a window that exists.
--
-- Extension stacks from whichever is later, now() or the end of a period that
-- is still running. Paying for a second year in month eleven adds a year to
-- the end; it does not throw eleven months away.

create or replace function public.apply_payment(
  p_razorpay_order_id   text,
  p_razorpay_payment_id text,
  p_method              text default null,
  p_signature_verified  boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_order public.payment_orders;
  v_plan  public.billing_plans;
  v_sub   public.subscriptions;
  v_base  timestamptz;
  v_start timestamptz;
  v_end   timestamptz;
begin
  select * into v_order
    from public.payment_orders
   where razorpay_order_id = p_razorpay_order_id
   for update;

  if not found then
    raise exception 'no order % on this project', p_razorpay_order_id
      using errcode = 'P0002';
  end if;

  -- Already done. Both callers land here on the loser of the race, and so
  -- does every webhook Razorpay replays afterwards.
  if v_order.status = 'captured' then
    return public.entitlement_of(v_order.user_id);
  end if;

  if v_order.status = 'refunded' then
    raise exception 'order % was refunded', p_razorpay_order_id
      using errcode = '22023';
  end if;

  -- A payment id already spent on a different order is a mix-up, not a
  -- payment. Refusing here keeps one payment from buying two plans.
  if exists (
    select 1 from public.payment_orders
     where razorpay_payment_id = p_razorpay_payment_id
       and id <> v_order.id
  ) then
    raise exception 'payment % is already applied to another order',
      p_razorpay_payment_id using errcode = '23505';
  end if;

  select * into v_plan from public.billing_plans where id = v_order.plan_id;
  if not found then
    raise exception 'order % names a plan that no longer exists',
      p_razorpay_order_id using errcode = 'P0002';
  end if;

  update public.payment_orders
     set status              = 'captured',
         razorpay_payment_id = p_razorpay_payment_id,
         method              = coalesce(p_method, method),
         failure             = null,
         verified_at         = case when p_signature_verified
                                    then now() else verified_at end
   where id = v_order.id;

  select * into v_sub
    from public.subscriptions
   where user_id = v_order.user_id
   for update;

  -- Stack onto a period still running; otherwise start today.
  v_base := case
    when v_sub.status in ('active', 'cancelled')
     and v_sub.current_period_end > now()
    then v_sub.current_period_end
    else now()
  end;
  v_start := case when v_base > now() then v_sub.current_period_start else now() end;
  v_end   := v_base + make_interval(days => v_plan.period_days);

  insert into public.subscriptions as s (
    user_id, plan_id, status, source,
    current_period_start, current_period_end, cancelled_at,
    last_payment_id, last_order_id, history
  )
  values (
    v_order.user_id, v_plan.id, 'active', 'razorpay',
    v_start, v_end, null,
    p_razorpay_payment_id, v_order.id,
    jsonb_build_array(jsonb_build_object(
      'plan',         v_plan.id,
      'payment_id',   p_razorpay_payment_id,
      'amount_minor', v_order.amount_minor,
      'until',        v_end,
      'at',           now()
    ))
  )
  on conflict (user_id) do update
    set plan_id              = excluded.plan_id,
        status               = 'active',
        source               = 'razorpay',
        current_period_start = excluded.current_period_start,
        current_period_end   = excluded.current_period_end,
        -- A renewal un-cancels: somebody who paid again wants it.
        cancelled_at         = null,
        last_payment_id      = excluded.last_payment_id,
        last_order_id        = excluded.last_order_id,
        -- Capped, so a long-lived account cannot grow a row without limit.
        history = coalesce((
          select jsonb_agg(kept.e order by kept.n)
            from (
              select e, n
                from jsonb_array_elements(s.history || excluded.history)
                     with ordinality t(e, n)
               order by n desc
               limit 24
            ) kept
        ), excluded.history);

  return public.entitlement_of(v_order.user_id);
end;
$fn$;

revoke all on function public.apply_payment(text, text, text, boolean)
  from public, anon, authenticated;


-- The other direction: a refund, a chargeback, or support taking something
-- back. The period is ended rather than the row deleted, so the receipt and
-- the reason survive.
create or replace function public.revoke_payment(
  p_razorpay_order_id text,
  p_reason            text default 'refunded'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_order public.payment_orders;
begin
  select * into v_order
    from public.payment_orders
   where razorpay_order_id = p_razorpay_order_id
   for update;

  if not found then
    raise exception 'no order % on this project', p_razorpay_order_id
      using errcode = 'P0002';
  end if;

  update public.payment_orders
     set status  = 'refunded',
         failure = jsonb_build_object('reason', p_reason)
   where id = v_order.id;

  -- Only the subscription this order is actually paying for is ended. A
  -- refund of last year's payment must not cut short a period bought since.
  update public.subscriptions
     set status               = 'none',
         current_period_start = null,
         current_period_end   = null,
         cancelled_at         = now()
   where user_id = v_order.user_id
     and last_order_id = v_order.id;

  return public.entitlement_of(v_order.user_id);
end;
$fn$;

revoke all on function public.revoke_payment(text, text)
  from public, anon, authenticated;


-- 8. Realtime -----------------------------------------------------------------------
-- A changed subscription is announced on the owner's private topic,
-- `billing:<user id>`, exactly the way habits are on `habits:<user id>`.
--
-- It matters more here than it does for habits. The payment that makes
-- somebody Pro is applied by a webhook on a server the app is not talking to,
-- and it can land seconds after the app gave up waiting — or while the phone
-- was in a tunnel and the checkout callback never arrived at all. Without
-- this, the app finds out on its next launch. With it, the sheet turns Pro
-- under the person's thumb.
--
-- Orders are not broadcast: the app already knows about the order it made,
-- and the row carries the payer's method and error details.

create or replace function public.broadcast_subscription_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  perform realtime.broadcast_changes(
    'billing:' || new.user_id::text,  -- topic
    tg_op,                            -- event
    tg_op,                            -- operation
    tg_table_name,
    tg_table_schema,
    new,
    old
  );
  return null;
end;
$fn$;

revoke all on function public.broadcast_subscription_change()
  from public, anon, authenticated;

drop trigger if exists subscriptions_broadcast on public.subscriptions;
create trigger subscriptions_broadcast
  after insert or update on public.subscriptions
  for each row execute function public.broadcast_subscription_change();

-- A signed-in user may receive on exactly one billing topic: their own. There
-- is no insert policy, so no client can publish onto it — only the trigger
-- above, which runs as the function's owner.
drop policy if exists "billing_topic_receive_own" on realtime.messages;
create policy "billing_topic_receive_own"
  on realtime.messages
  for select
  to authenticated
  using (
    realtime.messages.extension = 'broadcast'
    and (select realtime.topic()) = 'billing:' || (select auth.uid())::text
  );


-- 9. Tidying ------------------------------------------------------------------------
-- Nothing depends on this running: entitlement() already compares against
-- now(), so an unexpired row is a cosmetic problem and not an access one. It
-- is here so the table reads truthfully to a human, and so `status = 'active'`
-- can be counted on in a dashboard query.
--
-- Optional, once pg_cron is enabled (Database → Extensions):
--   select cron.schedule('tide-expire-subscriptions', '17 3 * * *',
--                        'select public.expire_subscriptions();');
--   select cron.schedule('tide-prune-billing-events', '41 3 * * 0',
--                        'select public.prune_billing_events(90);');

create or replace function public.expire_subscriptions()
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_count integer;
begin
  update public.subscriptions
     set status = 'expired'
   where status in ('active', 'cancelled')
     and current_period_end <= now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$fn$;

revoke all on function public.expire_subscriptions()
  from public, anon, authenticated;


-- Webhook bodies are cleared once they are old enough to be no use. They hold
-- payer contact details, so this is a retention rule rather than housekeeping.
create or replace function public.prune_billing_events(p_days integer default 90)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_count integer;
begin
  delete from public.billing_events
   where received_at < now() - make_interval(days => greatest(coalesce(p_days, 90), 7));
  get diagnostics v_count = row_count;
  return v_count;
end;
$fn$;

revoke all on function public.prune_billing_events(integer)
  from public, anon, authenticated;


-- 10. The service role ----------------------------------------------------------------
-- Supabase grants EXECUTE on new public functions to every role by default, and
-- the `revoke ... from public, anon, authenticated` lines above are what take
-- that back from the app. The Edge Functions reach these through the service
-- role, which the revokes do not name — but saying so explicitly is the
-- difference between a privilege that is intended and one that is left over.
--
-- `entitlement_of` is included because razorpay-verify-payment reads an
-- account's entitlement back after recording a failed attempt.

grant execute on function public.entitlement_of(uuid)                      to service_role;
grant execute on function public.apply_payment(text, text, text, boolean)  to service_role;
grant execute on function public.revoke_payment(text, text)                to service_role;
grant execute on function public.expire_subscriptions()                    to service_role;
grant execute on function public.prune_billing_events(integer)             to service_role;
