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
  --  7b. cancel_subscription()    the only two writes the app itself may make,
  --      resume_subscription()    and neither can grant anything
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


  -- 0. Upgrades ---------------------------------------------------------------------
  -- This whole file is written to be pasted again over a project that already has
  -- an earlier version of it: every table is `if not exists` and the plan seed is
  -- an upsert. Columns are the one thing that pattern cannot reach — `create table
  -- if not exists` on a table that exists adds nothing — so anything added after
  -- the first release is also spelled out here as an `alter`.
  --
  -- All of it is `if exists` / `if not exists`, so on a fresh database this whole
  -- section does nothing at all and the creates below do the work. It has to run
  -- *before* section 6, because `entitlement_of` reads columns that only exist
  -- once these have run, and a `language sql` function is validated the moment it
  -- is created.

  alter table if exists public.billing_plans
    add column if not exists billing_mode text not null default 'auto';
  alter table if exists public.billing_plans
    drop constraint if exists billing_plans_billing_mode_check;
  alter table if exists public.billing_plans
    add constraint billing_plans_billing_mode_check
    check (billing_mode in ('one_time', 'auto'));

  alter table if exists public.payment_orders
    add column if not exists kind text not null default 'order';
  alter table if exists public.payment_orders
    add column if not exists razorpay_subscription_id text;
  alter table if exists public.payment_orders
    add column if not exists razorpay_invoice_id text;
  -- A renewal has no order of ours to point at; see the column's own comment.
  alter table if exists public.payment_orders
    alter column razorpay_order_id drop not null;
  alter table if exists public.payment_orders
    drop constraint if exists payment_orders_has_an_identity;
  alter table if exists public.payment_orders
    add constraint payment_orders_has_an_identity
    check (razorpay_order_id is not null or razorpay_subscription_id is not null);

  alter table if exists public.subscriptions
    add column if not exists mandate_id text;
  -- 'past_due' and 'halted' arrived with auto-pay. Dropped and re-added rather
  -- than altered: a check constraint has no in-place widening.
  alter table if exists public.subscriptions
    drop constraint if exists subscriptions_status_check;
  alter table if exists public.subscriptions
    add constraint subscriptions_status_check
    check (status in ('none', 'active', 'cancelled', 'past_due', 'halted', 'expired'));


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
    -- How the money arrives. 'one_time' is a prepaid period bought with an
    -- order; 'auto' is a Razorpay Subscription with a mandate behind it that
    -- debits on its own. Both grant through the same period arithmetic, so
    -- entitlement never has to know which rail paid for it.
    billing_mode text not null default 'auto'
                  check (billing_mode in ('one_time', 'auto')),
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
  );

  -- The two Tide Pro plans. Change a price here and in
  -- `lib/config/plan_catalog.dart` together — the app quotes it and the server
  -- charges it, and `test/plan_catalog_test.dart` is what catches the two
  -- drifting apart.
  insert into public.billing_plans
    (id, name, interval, period_days, amount_minor, currency, sort, billing_mode)
  values
    ('pro_monthly', 'Tide Pro · monthly', 'month',  30,  10000, 'INR', 1, 'auto'),
    ('pro_yearly',  'Tide Pro · yearly',  'year',  365,  49900, 'INR', 2, 'auto')
  on conflict (id) do update
    set name         = excluded.name,
        interval     = excluded.interval,
        period_days  = excluded.period_days,
        amount_minor = excluded.amount_minor,
        currency     = excluded.currency,
        sort         = excluded.sort,
        billing_mode = excluded.billing_mode,
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
    -- Nullable since auto-pay. A renewal is charged by Razorpay against an
    -- order *it* created from the subscription, so there is no order of ours to
    -- point at -- the identity of such a row is its subscription and its
    -- payment. The check at the foot of the table is what stops a row having
    -- neither.
    razorpay_order_id   text unique
                          check (razorpay_order_id is null
                                or char_length(razorpay_order_id) between 4 and 64),
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
    -- Auto-pay. `kind` says which rail the row is a receipt for; the
    -- subscription id ties a renewal back to its mandate, and the invoice id is
    -- what Razorpay's own dashboard calls that charge.
    kind                text not null default 'order'
                          check (kind in ('order', 'subscription')),
    razorpay_subscription_id text
                          check (razorpay_subscription_id is null
                                or char_length(razorpay_subscription_id) between 4 and 64),
    razorpay_invoice_id text unique
                          check (razorpay_invoice_id is null
                                or char_length(razorpay_invoice_id) between 4 and 64),
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    -- A receipt names whatever it was paid against, on either rail.
    constraint payment_orders_has_an_identity
      check (razorpay_order_id is not null
            or razorpay_subscription_id is not null)
  );

  create index if not exists payment_orders_user_created_idx
    on public.payment_orders (user_id, created_at desc);

  -- Deliberately not a unique index: somebody who abandons a UPI attempt and
  -- starts a card one has two open orders, both legitimate, and only one of
  -- them will ever be captured.
  create index if not exists payment_orders_open_idx
    on public.payment_orders (user_id)
    where status in ('created', 'attempted', 'authorized');

  create index if not exists payment_orders_subscription_idx
    on public.payment_orders (razorpay_subscription_id, created_at desc)
    where razorpay_subscription_id is not null;


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
  --   'past_due'   an auto-debit did not go through and Razorpay is retrying.
  --                The period already paid for keeps running: a card that fails
  --                on the 30th does not undo the month paid for on the 1st, and
  --                taking Pro away mid-retry is how somebody pays twice
  --   'halted'     Razorpay has given up retrying. Same rule — the paid period
  --                runs out on its own date and nothing renews after it
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
                          check (status in ('none', 'active', 'cancelled',
                                            'past_due', 'halted', 'expired')),
    source               text not null default 'razorpay'
                          check (source in ('razorpay', 'promo', 'manual')),
    current_period_start timestamptz,
    current_period_end   timestamptz,
    cancelled_at         timestamptz,
    -- The payment that last extended it, and the order that payment belongs to.
    last_payment_id      text,
    last_order_id        uuid references public.payment_orders (id) on delete set null,
    -- The Razorpay subscription currently paying for this row, when one is.
    -- Null means the period was bought outright, which is what every account
    -- from before auto-pay looks like -- and what decides whether cancelling is
    -- a local write or a call to Razorpay.
    mandate_id           text,
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
    where status in ('active', 'cancelled', 'past_due', 'halted');


  -- 3b. Mandates --------------------------------------------------------------------
  -- One row per Razorpay Subscription: the standing permission to debit, and
  -- whatever Razorpay last said about it.
  --
  -- A separate table rather than more columns on `subscriptions`, because the two
  -- do not have the same lifetime. A person can authorise a mandate, cancel it,
  -- and authorise another one next year; `subscriptions` is one row that says what
  -- they hold *now*, and this is the history of the instruments that paid for it.
  --
  -- `subscriptions.mandate_id` points here by id and deliberately carries **no
  -- foreign key**. Pruning an old mandate must never be able to take somebody's
  -- plan with it, and the period in `subscriptions` is true whether or not the
  -- thing that bought it is still on file.
  --
  -- `status` is Razorpay's own vocabulary, kept verbatim:
  --   'created'        the subscription exists, nobody has authorised it yet
  --   'authenticated'  the mandate is registered; the first debit is pending
  --   'active'         charging normally
  --   'pending'        a debit failed and Razorpay is retrying it
  --   'halted'         Razorpay has stopped retrying
  --   'paused'         paused by us or by them
  --   'cancelled'      finished early, and **not reversible at Razorpay**
  --   'completed'      ran its `total_count` of cycles
  --   'expired'        never authorised before it lapsed

  create table if not exists public.billing_mandates (
    razorpay_subscription_id text primary key
                              check (char_length(razorpay_subscription_id) between 4 and 64),
    user_id                  uuid not null references auth.users (id) on delete cascade,
    plan_id                  text not null references public.billing_plans (id),
    status                   text not null default 'created'
                              check (status in ('created', 'authenticated', 'active',
                                                'pending', 'halted', 'paused',
                                                'cancelled', 'completed', 'expired')),
    -- When Razorpay will try next, and the end of the cycle it has paid for.
    -- Both come from Razorpay rather than being worked out here: the cycle is
    -- calendar-based at their end, and a date this table guessed would drift off
    -- the date the money actually moves.
    charge_at                timestamptz,
    current_end              timestamptz,
    paid_count               integer not null default 0,
    total_count              integer,
    -- The payment that registered the mandate. On a card e-mandate this is a
    -- real first charge; on some rails it is a zero-rupee authorisation.
    auth_payment_id          text,
    -- Razorpay's hosted authorisation page. Kept because it is the only way to
    -- rescue a mandate the app failed to finish registering.
    short_url                text,
    -- When the person asked to stop. Distinct from `status = 'cancelled'`, which
    -- is Razorpay's answer: between the two is the window where we have asked and
    -- they have not confirmed, and the app must not claim it is done.
    cancel_requested_at      timestamptz,
    notes                    jsonb not null default '{}'::jsonb,
    created_at               timestamptz not null default now(),
    updated_at               timestamptz not null default now()
  );

  create index if not exists billing_mandates_user_idx
    on public.billing_mandates (user_id, created_at desc);

  -- The live one for an account, which is what create-subscription checks before
  -- opening a second. Partial and unique: somebody may hold many dead mandates
  -- and at most one that can still charge them.
  create unique index if not exists billing_mandates_one_live_per_user_idx
    on public.billing_mandates (user_id)
    where status in ('created', 'authenticated', 'active', 'pending');


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
  -- A mandate is the person's own standing instruction; they may read it and
  -- nothing else. There is no insert or update policy, here or anywhere: the
  -- rows are written by an Edge Function holding the service role, after a
  -- signature has been checked.
  alter table public.billing_mandates enable row level security;

  drop policy if exists "billing_mandates_select_own" on public.billing_mandates;
  create policy "billing_mandates_select_own"
    on public.billing_mandates
    for select
    to authenticated
    using (user_id = (select auth.uid()));

  create policy "subscriptions_select_own"
    on public.subscriptions
    for select
    to authenticated
    using ((select auth.uid()) = user_id);

  -- billing_events gets no policy at all. RLS is on and nothing is permitted,
  -- which is the right amount of access to a table of raw webhook bodies.

  revoke all on table public.billing_mandates from public, anon, authenticated;
  grant select on table public.billing_mandates to authenticated;

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
      -- Every status but a refund ('none') and a period already run out
      -- ('expired') is Pro *while the period runs*, because the period is what
      -- was paid for. A failed renewal is a reason to stop renewing, never a
      -- reason to claw back days somebody already holds. Mirrored exactly in
      -- Entitlement.isProAt -- the two are one expression on purpose.
      'pro', coalesce(
        s.status in ('active', 'cancelled', 'past_due', 'halted')
          and s.current_period_end > now(),
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
      -- Auto-pay. `auto_renews` is the difference between "ends on 12 October"
      -- and "renews on 12 October" -- the most important line on the billing
      -- screen, and not something the status alone can answer.
      'auto_renews',          coalesce(
                                m.status in ('authenticated', 'active', 'pending'),
                                false
                              ),
      'next_charge_at',       case
                                when m.status in ('authenticated', 'active', 'pending')
                                then m.charge_at
                              end,
      'mandate_status',       m.status,
      -- Sent so the app can work out how long is left without trusting the
      -- device's clock, which people change.
      'server_time',          now()
    )
    from (select 1) one
    left join public.subscriptions s on s.user_id = p_user_id
    left join public.billing_plans p on p.id = s.plan_id
    left join public.billing_mandates m
          on m.razorpay_subscription_id = s.mandate_id;
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
                  'kind',         o.kind,
                  'created_at',   o.created_at
                )
                order by o.created_at desc
              )
          from (
            select *
              from public.payment_orders
            where user_id = (select auth.uid())
              and status in ('captured', 'refunded', 'failed')
              -- A payment sheet that was closed is not a failed payment, and it
              -- is certainly not a receipt. The app records a dismissal as a
              -- failed order so the order stops being open and the reason is
              -- written down — but surfacing it here would put a permanent
              -- "Payment failed" line in somebody's history every time they
              -- looked at the price and changed their mind.
              and not (status = 'failed' and failure ->> 'code' = 'cancelled')
            order by created_at desc
            limit least(greatest(coalesce(p_limit, 20), 1), 100)
          ) o
      ), '[]'::jsonb)
    );
  $fn$;

  revoke all on function public.billing_snapshot(integer) from public, anon, authenticated;
  grant execute on function public.billing_snapshot(integer) to authenticated;


  -- 7. Granting and revoking ------------------------------------------------------------

  -- The period arithmetic, in one place, because there are now two ways to pay
  -- for one and they must agree to the second.
  --
  -- `apply_payment` (an order somebody paid) and `apply_subscription_charge` (a
  -- mandate debiting on its own) both end here. Two copies of "stack onto a
  -- period still running" would be two copies of the only sum in this file that
  -- somebody can lose money to.
  --
  -- Extension stacks from whichever is later, now() or the end of a period still
  -- running. Paying for a second year in month eleven adds a year to the end; it
  -- does not throw eleven months away.
  --
  -- `p_until` is for auto-pay: Razorpay owns the calendar there, so the period
  -- ends when *they* say the cycle does rather than on a count of days from here.
  -- It can only ever move the end later — a cycle end that arrives earlier than
  -- the period already held is ignored, so a mandate started on top of a prepaid
  -- year cannot shorten the year.

  create or replace function public.extend_period(
    p_user_id      uuid,
    p_plan_id      text,
    p_payment_id   text,
    p_order_id     uuid,
    p_amount_minor integer,
    p_until        timestamptz default null,
    p_mandate_id   text default null
  )
  returns void
  language plpgsql
  security definer
  set search_path = ''
  as $fn$
  declare
    v_plan  public.billing_plans;
    v_sub   public.subscriptions;
    v_base  timestamptz;
    v_start timestamptz;
    v_end   timestamptz;
  begin
    select * into v_plan from public.billing_plans where id = p_plan_id;
    if not found then
      raise exception 'no plan % on this project', p_plan_id
        using errcode = 'P0002';
    end if;

    select * into v_sub
      from public.subscriptions
    where user_id = p_user_id
    for update;

    v_base := case
      when v_sub.status in ('active', 'cancelled', 'past_due', 'halted')
      and v_sub.current_period_end > now()
      then v_sub.current_period_end
      else now()
    end;
    v_start := case when v_base > now() then v_sub.current_period_start else now() end;
    v_end   := greatest(
      coalesce(p_until, v_base + make_interval(days => v_plan.period_days)),
      v_base
    );

    insert into public.subscriptions as s (
      user_id, plan_id, status, source,
      current_period_start, current_period_end, cancelled_at,
      last_payment_id, last_order_id, mandate_id, history
    )
    values (
      p_user_id, v_plan.id, 'active', 'razorpay',
      v_start, v_end, null,
      p_payment_id, p_order_id, p_mandate_id,
      jsonb_build_array(jsonb_build_object(
        'plan',         v_plan.id,
        'payment_id',   p_payment_id,
        'amount_minor', p_amount_minor,
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
          -- A payment un-cancels, and clears a failed-renewal state with it:
          -- somebody who just paid wants it, and the retry that was pending has
          -- either succeeded or been superseded.
          cancelled_at         = null,
          last_payment_id      = excluded.last_payment_id,
          last_order_id        = excluded.last_order_id,
          -- A one-off top-up on a mandated account must not forget the mandate.
          mandate_id           = coalesce(excluded.mandate_id, s.mandate_id),
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
  end;
  $fn$;

  -- Never granted to anybody, not even the service role. It is reached only from
  -- inside the two `security definer` functions below, which run as this
  -- function's owner; a caller who could reach it directly could name their own
  -- period end.
  revoke all on function
    public.extend_period(uuid, text, text, uuid, integer, timestamptz, text)
    from public, anon, authenticated, service_role;


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

    perform public.extend_period(
      p_user_id      => v_order.user_id,
      p_plan_id      => v_plan.id,
      p_payment_id   => p_razorpay_payment_id,
      p_order_id     => v_order.id,
      p_amount_minor => v_order.amount_minor
    );

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



  -- 7a. Auto-pay: a mandate debiting on its own ------------------------------------------
  -- The renewal equivalent of `apply_payment`, and the reason `payment_orders`
  -- stopped requiring an order id. Nobody opened an order for this charge: the
  -- mandate came due, Razorpay debited the card, and `subscription.charged`
  -- arrived. The receipt row is written here rather than beforehand.
  --
  -- **Idempotency moves.** `apply_payment` keys on its order reaching 'captured'
  -- under `for update`, which needs a row that already exists. There is none
  -- here, so the key is the payment id itself — unique on `payment_orders` — and
  -- the mandate row is what is locked while the check and the insert happen.
  -- Razorpay replays `subscription.charged`, and the webhook ledger already
  -- stops an identical *delivery*; this is what stops a second delivery of the
  -- same charge under a new event id.
  --
  -- Only ever reached from razorpay-webhook. There is no device callback for a
  -- renewal — by definition nobody was holding the phone.

  create or replace function public.apply_subscription_charge(
    p_razorpay_subscription_id text,
    p_razorpay_payment_id      text,
    p_razorpay_invoice_id      text default null,
    p_amount_minor             integer default null,
    p_method                   text default null,
    p_current_end              timestamptz default null,
    p_charge_at                timestamptz default null,
    p_paid_count               integer default null
  )
  returns jsonb
  language plpgsql
  security definer
  set search_path = ''
  as $fn$
  declare
    v_mandate public.billing_mandates;
    v_plan    public.billing_plans;
    v_order   uuid;
    v_until   timestamptz;
  begin
    select * into v_mandate
      from public.billing_mandates
    where razorpay_subscription_id = p_razorpay_subscription_id
    for update;

    if not found then
      raise exception 'no mandate % on this project', p_razorpay_subscription_id
        using errcode = 'P0002';
    end if;

    -- Already applied. Every later delivery of this charge lands here.
    if exists (
      select 1 from public.payment_orders
      where razorpay_payment_id = p_razorpay_payment_id
    ) then
      return public.entitlement_of(v_mandate.user_id);
    end if;

    select * into v_plan from public.billing_plans where id = v_mandate.plan_id;
    if not found then
      raise exception 'mandate % names a plan that no longer exists',
        p_razorpay_subscription_id using errcode = 'P0002';
    end if;

    insert into public.payment_orders (
      user_id, plan_id, kind,
      razorpay_subscription_id, razorpay_invoice_id, razorpay_payment_id,
      amount_minor, currency, status, method, notes
    )
    values (
      v_mandate.user_id, v_plan.id, 'subscription',
      p_razorpay_subscription_id, p_razorpay_invoice_id, p_razorpay_payment_id,
      coalesce(p_amount_minor, v_plan.amount_minor), v_plan.currency,
      'captured', p_method,
      jsonb_build_object('tide_user_id', v_mandate.user_id,
                        'tide_plan_id', v_plan.id)
    )
    returning id into v_order;
    -- `verified_at` is deliberately left null. The webhook signature proves the
    -- delivery, not a checkout; only razorpay-verify-payment can claim that, and
    -- nothing was checked out here.

    -- Two days of slack on Razorpay's own cycle end. They debit *at* the cycle
    -- end, so granting exactly to it leaves a gap the width of however long the
    -- webhook took to arrive — and that gap is Pro flickering off for somebody
    -- whose payment went through perfectly.
    v_until := case
      when p_current_end is not null then p_current_end + interval '2 days'
    end;

    perform public.extend_period(
      p_user_id      => v_mandate.user_id,
      p_plan_id      => v_plan.id,
      p_payment_id   => p_razorpay_payment_id,
      p_order_id     => v_order,
      p_amount_minor => coalesce(p_amount_minor, v_plan.amount_minor),
      p_until        => v_until,
      p_mandate_id   => p_razorpay_subscription_id
    );

    update public.billing_mandates
      set status      = 'active',
          charge_at   = coalesce(p_charge_at, charge_at),
          current_end = coalesce(p_current_end, current_end),
          paid_count  = greatest(coalesce(p_paid_count, paid_count + 1), paid_count),
          auth_payment_id = coalesce(auth_payment_id, p_razorpay_payment_id)
    where razorpay_subscription_id = p_razorpay_subscription_id;

    return public.entitlement_of(v_mandate.user_id);
  end;
  $fn$;

  revoke all on function public.apply_subscription_charge(
    text, text, text, integer, text, timestamptz, timestamptz, integer)
    from public, anon, authenticated;


  -- Everything a subscription webhook says that is *not* money arriving.
  --
  -- The mapping onto `subscriptions.status` is the whole content of this
  -- function, and the rule behind it is one sentence: **a mandate going wrong
  -- never shortens a period already paid for.** A failed debit, a halt, a
  -- cancellation — all of them mean "nothing more is coming", which in this
  -- schema is what 'past_due', 'halted' and 'cancelled' say, and all three are
  -- Pro until `current_period_end` passes.
  --
  -- Structurally incapable of granting anything: no SET list below names
  -- current_period_end, current_period_start, plan_id or history, so no sequence
  -- of webhook deliveries — in any order, replayed any number of times — can buy
  -- anybody a day. `test/billing_sql_test.dart` holds it to that.

  create or replace function public.sync_mandate_state(
    p_razorpay_subscription_id text,
    p_status                   text,
    p_charge_at                timestamptz default null,
    p_current_end              timestamptz default null,
    p_paid_count               integer default null,
    p_auth_payment_id          text default null
  )
  returns jsonb
  language plpgsql
  security definer
  set search_path = ''
  as $fn$
  declare
    v_mandate public.billing_mandates;
    v_status  text;
    v_known   text;
  begin
    select * into v_mandate
      from public.billing_mandates
    where razorpay_subscription_id = p_razorpay_subscription_id
    for update;

    if not found then
      raise exception 'no mandate % on this project', p_razorpay_subscription_id
        using errcode = 'P0002';
    end if;

    -- A status this file has never heard of keeps the one it had.
    --
    -- Forgiving on purpose, the same way `HabitRows.parseHabit` is. Razorpay can
    -- add a subscription status whenever they like, and the alternative here is
    -- ugly: the value fails the column's CHECK, this function raises, the
    -- webhook returns 500, and Razorpay's retry is then swallowed as a duplicate
    -- by the event ledger — so a delivery that should have been a no-op becomes
    -- a delivery that is lost. The dates are still worth taking from it.
    v_known := case
      when p_status in ('created', 'authenticated', 'active', 'pending',
                        'halted', 'paused', 'cancelled', 'completed', 'expired')
      then p_status
      else v_mandate.status
    end;

    update public.billing_mandates
      set status          = v_known,
          charge_at       = coalesce(p_charge_at, charge_at),
          current_end     = coalesce(p_current_end, current_end),
          paid_count      = greatest(coalesce(p_paid_count, paid_count), paid_count),
          auth_payment_id = coalesce(auth_payment_id, p_auth_payment_id)
    where razorpay_subscription_id = p_razorpay_subscription_id;

    -- 'paused' is folded into 'cancelled' on purpose: Tide has no paused plan,
    -- and from the person's side the two are the same sentence — the days you
    -- hold are yours and nothing further is coming.
    --
    -- Anything not in this list leaves `subscriptions` alone: an unrecognised
    -- status is not a reason to decide somebody's plan has ended.
    v_status := case v_known
      when 'active'        then 'active'
      when 'authenticated' then 'active'
      when 'pending'       then 'past_due'
      when 'halted'        then 'halted'
      when 'cancelled'     then 'cancelled'
      when 'paused'        then 'cancelled'
      when 'completed'     then 'cancelled'
      when 'expired'       then 'cancelled'
    end;

    if v_status is not null then
      update public.subscriptions
        set status       = v_status,
            cancelled_at = case
              when v_status = 'cancelled' then coalesce(cancelled_at, now())
              when v_status = 'active'    then null
              else cancelled_at
            end
      where user_id = v_mandate.user_id
        and mandate_id = p_razorpay_subscription_id
        -- A row whose period has already run out is left as it lies: 'expired'
        -- is the truth about it, and writing 'cancelled' over that would put a
        -- plan back into the set of things the app offers to resume.
        and current_period_end > now();
    end if;

    return public.entitlement_of(v_mandate.user_id);
  end;
  $fn$;

  revoke all on function public.sync_mandate_state(
    text, text, timestamptz, timestamptz, integer, text)
    from public, anon, authenticated;

  -- 7b. What the person can do themselves ------------------------------------------
  -- The only two functions in this file an `authenticated` caller may execute that
  -- write anything at all. They are safe to hand out because of what they are
  -- structurally unable to do, not because of what they check:
  --
  --   * Neither takes an argument. There is no user id to forge — the row is
  --     chosen by auth.uid() and nothing else, and PostgREST has no parameter to
  --     put a stranger's uuid into. A cancel_subscription(p_user_id uuid) is
  --     broken by the first caller who passes somebody else's id; this shape
  --     makes that mistake unavailable.
  --   * Neither SET list mentions plan_id, current_period_start,
  --     current_period_end, source, last_payment_id or history. A period cannot
  --     be extended by a function that does not name the column.
  --   * 'active' and 'cancelled' are the same answer to entitlement_of(): both
  --     are Pro while current_period_end is in the future, neither is after. These
  --     two move a row between those states and nowhere else, so no sequence of
  --     calls — any order, any number of times — changes whether the caller is
  --     Pro or for how long.
  --   * Both are idempotent by the shape of the WHERE rather than by a check
  --     somebody has to remember to write.
  --
  -- Deliberately VOLATILE (plpgsql's default — do not mark these `stable`).
  -- PostgREST only accepts POST for a volatile function; `stable` would expose a
  -- state change to GET, which is a CSRF-shaped surface.
  --
  -- **What cancelling means here.** These are prepaid periods with no mandate, so
  -- there is no charge to stop. Cancelling records an intention and keeps every
  -- day that was paid for; entitlement_of already treats 'cancelled' as Pro until
  -- the period ends, which is why nothing in section 6 changes. The one thing the
  -- person can actually see is that the app stops offering to renew.

  -- The implementation, by user id, for the caller that has already done the part
  -- this cannot do.
  --
  -- It takes a uuid where the app-facing wrapper below takes none, and that is
  -- safe for the opposite reason: this one is reachable only by the service role,
  -- which can read and write every row in the database anyway. A uuid parameter
  -- is only a forgeable hole on a function `authenticated` can call.
  create or replace function public.cancel_subscription_for(p_user_id uuid)
  returns jsonb
  language plpgsql
  security definer
  set search_path = ''
  as $fn$
  begin
    if p_user_id is null then
      raise exception 'cancel_subscription_for needs a user' using errcode = '22004';
    end if;

    -- No row, a free account, a period that has run out, or one already
    -- cancelled: nothing matches and the call is a read. A plan mid-retry
    -- ('past_due') or given up on ('halted') can still be cancelled — it is the
    -- most likely moment somebody wants to.
    update public.subscriptions
      set status       = 'cancelled',
          cancelled_at = now()
    where user_id = p_user_id
      and status in ('active', 'past_due', 'halted')
      and current_period_end > now();

    return public.entitlement_of(p_user_id);
  end;
  $fn$;

  revoke all on function public.cancel_subscription_for(uuid)
    from public, anon, authenticated;


  -- What the app calls, pinned to whoever is holding the token.
  --
  -- **It refuses a plan with a mandate behind it**, and that refusal is the
  -- load-bearing line. Marking a row 'cancelled' while the standing instruction
  -- is still registered at Razorpay produces the one outcome worse than either
  -- state alone: the app says nothing more will be charged, and the money keeps
  -- going out every month. Stopping an auto-debit means telling Razorpay, which
  -- no SQL function can do, so the only way through is
  -- razorpay-cancel-subscription — which cancels there first and calls
  -- cancel_subscription_for here second.
  create or replace function public.cancel_subscription()
  returns jsonb
  language plpgsql
  security definer
  set search_path = ''
  as $fn$
  declare
    v_user uuid := (select auth.uid());
  begin
    if v_user is null then
      raise exception 'cancel_subscription needs a signed-in caller'
        using errcode = '28000';
    end if;

    if exists (
      select 1 from public.subscriptions
      where user_id = v_user
        and mandate_id is not null
    ) then
      raise exception 'this plan is cancelled through razorpay'
        using errcode = '42501';
    end if;

    return public.cancel_subscription_for(v_user);
  end;
  $fn$;

  revoke all on function public.cancel_subscription()
    from public, anon, authenticated;
  grant execute on function public.cancel_subscription() to authenticated;


  -- The undo. 'cancelled' -> 'active', and only that: a row that is 'none' or
  -- 'expired' has no period to resume, and a cancelled row whose period has run
  -- out is not resumed either — it is over, and 'active' with a date in the past
  -- is a lie every dashboard query would then have to see through.
  --
  -- Note that a refunded row is 'none' *and* has both period columns nulled by
  -- revoke_payment, so it fails this WHERE three separate ways. A refund cannot
  -- be undone by the person who was refunded.
  create or replace function public.resume_subscription_for(p_user_id uuid)
  returns jsonb
  language plpgsql
  security definer
  set search_path = ''
  as $fn$
  begin
    if p_user_id is null then
      raise exception 'resume_subscription_for needs a user' using errcode = '22004';
    end if;

    update public.subscriptions
      set status       = 'active',
          cancelled_at = null
    where user_id = p_user_id
      and status = 'cancelled'
      and current_period_end > now();

    return public.entitlement_of(p_user_id);
  end;
  $fn$;

  revoke all on function public.resume_subscription_for(uuid)
    from public, anon, authenticated;


  -- The app-facing undo, and it is only an undo for a prepaid period.
  --
  -- **A cancelled mandate cannot be resumed, here or anywhere.** Razorpay treats
  -- a cancelled subscription as finished — there is no un-cancel call — so there
  -- is no mandate left to put back, and a row flipped to 'active' would be the
  -- app promising a renewal that nothing is going to perform. Starting again
  -- means authorising a new mandate, which is a checkout, not a button. So this
  -- refuses the same way cancel does and the app sends those accounts to the
  -- paywall instead.
  create or replace function public.resume_subscription()
  returns jsonb
  language plpgsql
  security definer
  set search_path = ''
  as $fn$
  declare
    v_user uuid := (select auth.uid());
  begin
    if v_user is null then
      raise exception 'resume_subscription needs a signed-in caller'
        using errcode = '28000';
    end if;

    if exists (
      select 1 from public.subscriptions
      where user_id = v_user
        and mandate_id is not null
    ) then
      raise exception 'a cancelled mandate cannot be resumed'
        using errcode = '42501';
    end if;

    return public.resume_subscription_for(v_user);
  end;
  $fn$;

  revoke all on function public.resume_subscription()
    from public, anon, authenticated;
  grant execute on function public.resume_subscription() to authenticated;

  -- The no-argument pair is not granted to service_role, and that is on purpose:
  -- both read auth.uid(), which is null for the service role, so a grant there
  -- would be a privilege that does nothing. The Edge Functions use the `_for`
  -- implementations above instead, after doing the half that has to happen at
  -- Razorpay.


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

  -- Auto-pay. `apply_subscription_charge` is the renewal grant path and
  -- `sync_mandate_state` everything else a subscription webhook says;
  -- `cancel_subscription_for` / `resume_subscription_for` are what
  -- razorpay-cancel-subscription and razorpay-resume-subscription call once they
  -- have dealt with Razorpay.
  --
  -- `extend_period` is deliberately absent: it is revoked from service_role too,
  -- and reached only from inside the two definer functions that grant.
  grant execute on function public.apply_subscription_charge(
    text, text, text, integer, text, timestamptz, timestamptz, integer)         to service_role;
  grant execute on function public.sync_mandate_state(
    text, text, timestamptz, timestamptz, integer, text)                        to service_role;
  grant execute on function public.cancel_subscription_for(uuid)                to service_role;
  grant execute on function public.resume_subscription_for(uuid)                to service_role;
