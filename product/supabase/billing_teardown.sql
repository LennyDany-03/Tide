-- Tide — remove the Tide Pro billing schema.
--
-- Tide ships free on Google Play. `billing_setup.sql` is gone from the repo
-- and this is what takes the same objects out of a project it was already
-- pasted into. Run it once in the Supabase SQL editor; it is idempotent, so
-- a second run is a no-op.
--
-- ARCHIVE FIRST. This drops payment history. Before running it, export the
-- five tables — Table Editor → each table → Download CSV, or from a linked
-- CLI:
--
--   supabase db dump --data-only \
--     -t public.payment_orders -t public.subscriptions \
--     -t public.billing_mandates -t public.billing_events \
--     -t public.billing_plans -f billing-archive.sql
--
-- AND UNDEPLOY THE EDGE FUNCTIONS FIRST. A live `razorpay-webhook` pointed
-- at a schema that no longer exists 500s on every delivery and Razorpay
-- retries it for days:
--
--   supabase functions delete razorpay-create-order
--   supabase functions delete razorpay-create-subscription
--   supabase functions delete razorpay-verify-payment
--   supabase functions delete razorpay-webhook
--   supabase functions delete razorpay-cancel-subscription
--   supabase secrets unset RAZORPAY_KEY_ID RAZORPAY_KEY_SECRET \
--     RAZORPAY_WEBHOOK_SECRET RAZORPAY_PLAN_PRO_MONTHLY \
--     RAZORPAY_PLAN_PRO_YEARLY
--
-- !! public.touch_updated_at() IS NOT DROPPED HERE, DELIBERATELY. !!
-- `billing_setup.sql` created it, but so do `auth_setup.sql` and
-- `habits_setup.sql`, and `profiles`, `habits` and `habit_entries` all have
-- live triggers on it. Dropping it with `cascade` silently takes those
-- triggers with it and stops `updated_at` moving, which is what the habit
-- sync orders writes by. Leave it alone.

begin;

-- 1. The realtime policy. It is the one billing object that does not live on
--    a billing table, so `drop table ... cascade` would not reach it and it
--    would sit on realtime.messages forever, granting a topic nothing
--    publishes to.
drop policy if exists "billing_topic_receive_own" on realtime.messages;

-- 2. The functions. Explicit signatures, because several are overload-shaped
--    and `drop function` without them is ambiguous. Table triggers go with
--    their tables in step 3.
drop function if exists public.entitlement_of(uuid) cascade;
drop function if exists public.entitlement() cascade;
drop function if exists public.billing_snapshot(integer) cascade;

drop function if exists public.extend_period(
  uuid, text, text, uuid, integer, timestamptz, text
) cascade;

drop function if exists public.apply_payment(text, text, text, boolean) cascade;
drop function if exists public.revoke_payment(text, text) cascade;

drop function if exists public.apply_subscription_charge(
  text, text, text, integer, text, timestamptz, timestamptz, integer
) cascade;

drop function if exists public.sync_mandate_state(
  text, text, timestamptz, timestamptz, integer, text
) cascade;

drop function if exists public.cancel_subscription_for(uuid) cascade;
drop function if exists public.cancel_subscription() cascade;
drop function if exists public.resume_subscription_for(uuid) cascade;
drop function if exists public.resume_subscription() cascade;

drop function if exists public.broadcast_subscription_change() cascade;
drop function if exists public.expire_subscriptions() cascade;
drop function if exists public.prune_billing_events(integer) cascade;

-- 3. The tables, children first. Their indexes, RLS policies and
--    `*_touch_updated_at` / `subscriptions_broadcast` triggers go with them.
drop table if exists public.billing_events cascade;
drop table if exists public.payment_orders cascade;
drop table if exists public.billing_mandates cascade;
drop table if exists public.subscriptions cascade;
drop table if exists public.billing_plans cascade;

commit;

-- Verify. Both should come back with no rows.
--
--   select tablename from pg_tables
--   where schemaname = 'public'
--     and (tablename like 'billing%' or tablename in
--          ('payment_orders', 'subscriptions'));
--
--   select p.proname from pg_proc p
--   join pg_namespace n on n.oid = p.pronamespace
--   where n.nspname = 'public'
--     and p.proname in (
--       'entitlement', 'entitlement_of', 'billing_snapshot', 'extend_period',
--       'apply_payment', 'revoke_payment', 'apply_subscription_charge',
--       'sync_mandate_state', 'cancel_subscription', 'cancel_subscription_for',
--       'resume_subscription', 'resume_subscription_for',
--       'broadcast_subscription_change', 'expire_subscriptions',
--       'prune_billing_events');
--
-- And this one SHOULD still return a row — it is the shared trigger function
-- that habits and profiles depend on:
--
--   select proname from pg_proc p
--   join pg_namespace n on n.oid = p.pronamespace
--   where n.nspname = 'public' and p.proname = 'touch_updated_at';
