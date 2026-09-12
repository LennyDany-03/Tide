// Auto-pay, step 1 · Create the subscription.
//
// POST { plan: "pro_monthly" | "pro_yearly" }
//   → { subscription_id, amount_minor, currency, key_id, plan, short_url }
//
// Called by `SupabaseBillingService.startCheckout` for any plan whose
// `billing_mode` is 'auto'. The order-based sibling, `razorpay-create-order`,
// is still what a prepaid plan goes through and is unchanged.
//
// **The client does not name a price, and it does not name the Razorpay plan
// either.** It names a Tide plan id. The amount is read from `billing_plans`
// for display, and the Razorpay plan id comes from this function's secrets —
// because plan ids differ between test mode and live exactly the way the key
// id does, and a value with two environment-specific forms does not belong in
// a table that has one row per plan:
//
//   supabase secrets set RAZORPAY_PLAN_PRO_MONTHLY=plan_...
//   supabase secrets set RAZORPAY_PLAN_PRO_YEARLY=plan_...
//
// **One live mandate per account, enforced twice.** A partial unique index on
// `billing_mandates` makes a second live row impossible, and the branch below
// decides what to do instead of hitting it:
//
//   * a mandate already authorised → refused, so nobody ends up with two
//     standing instructions and two debits a month;
//   * a mandate still at 'created' for the same plan → handed back, which is
//     the ordinary case it looks like a guard against: somebody dismissed the
//     authorisation sheet and came back to it. Without this, dismissing the
//     sheet once would lock the account out of subscribing for good;
//   * a mandate still at 'created' for a *different* plan → cancelled at
//     Razorpay and replaced, because that one is somebody changing their mind
//     between the two prices.

import { fail, json, preflight } from '../_shared/http.ts';
import {
  adminClient,
  atTime,
  callerId,
  cancelSubscription,
  createSubscription,
  RazorpayError,
} from '../_shared/razorpay.ts';

/// How many cycles a subscription is opened for. Razorpay requires a count —
/// there is no "until cancelled" — so this is one large enough to be that in
/// practice: ten years of months, or ten years of years.
const TOTAL_COUNT = { month: 120, year: 10 } as const;

Deno.serve(async (req: Request) => {
  const options = preflight(req);
  if (options) return options;

  try {
    const userId = await callerId(req);
    if (!userId) {
      return fail('unauthorised', 'Sign in before starting a payment.', 401);
    }

    const body = await req.json().catch(() => ({}));
    const planId = typeof body?.plan === 'string' ? body.plan : '';
    if (!planId) return fail('bad_request', 'No plan was named.', 400);

    const db = adminClient();

    const { data: plan, error: planError } = await db
      .from('billing_plans')
      .select('id, amount_minor, currency, interval, name, billing_mode')
      .eq('id', planId)
      .eq('active', true)
      .maybeSingle();

    if (planError) {
      return fail('server_error', 'The price list could not be read.', 500, planError.message);
    }
    if (!plan) return fail('unknown_plan', 'That plan is not on sale.', 404);
    if (plan.billing_mode !== 'auto') {
      // The app picks the function off the same column, so reaching here is a
      // build talking to a project whose price list has since changed.
      return fail(
        'wrong_rail',
        'That plan is bought outright, not subscribed to.',
        409,
      );
    }

    const razorpayPlanId = Deno.env.get(
      `RAZORPAY_PLAN_${plan.id.toUpperCase()}`,
    );
    if (!razorpayPlanId) {
      return fail(
        'server_error',
        'This plan is not set up for auto-pay yet.',
        500,
        `RAZORPAY_PLAN_${plan.id.toUpperCase()} is not set`,
      );
    }

    // --- A mandate this account already has ---------------------------------
    const { data: live } = await db
      .from('billing_mandates')
      .select('razorpay_subscription_id, plan_id, status, short_url')
      .eq('user_id', userId)
      .in('status', ['created', 'authenticated', 'active', 'pending'])
      .maybeSingle();

    if (live && live.status !== 'created') {
      return fail(
        'already_subscribed',
        'This account already has a subscription.',
        409,
      );
    }

    if (live && live.plan_id === plan.id) {
      return json({
        subscription_id: live.razorpay_subscription_id,
        amount_minor: plan.amount_minor,
        currency: plan.currency,
        key_id: Deno.env.get('RAZORPAY_KEY_ID'),
        plan: plan.id,
        short_url: live.short_url,
        reused: true,
      });
    }

    if (live) {
      // Unauthorised, and for the other plan. Cancelled at Razorpay first so
      // nothing is left dangling there, then dropped here — the row has never
      // paid for anything, so there is no receipt to preserve.
      try {
        await cancelSubscription(live.razorpay_subscription_id, {
          cancelAtCycleEnd: false,
        });
      } catch (error) {
        // A subscription Razorpay has already disposed of is not a problem to
        // report: the goal was for it to be gone.
        console.warn('Stale subscription not cancelled:', String(error));
      }
      await db
        .from('billing_mandates')
        .delete()
        .eq('razorpay_subscription_id', live.razorpay_subscription_id);
    }

    const interval = plan.interval === 'year' ? 'year' : 'month';
    const subscription = await createSubscription({
      planId: razorpayPlanId,
      totalCount: TOTAL_COUNT[interval],
      // Carried back on every webhook, which is what ties a delivery to an
      // account without a lookup — and what makes a mandate traceable even if
      // the row below failed to be written.
      notes: { tide_user_id: userId, tide_plan_id: plan.id },
    });

    const { error: writeError } = await db.from('billing_mandates').insert({
      razorpay_subscription_id: subscription.id,
      user_id: userId,
      plan_id: plan.id,
      status: subscription.status ?? 'created',
      charge_at: atTime(subscription.charge_at),
      current_end: atTime(subscription.current_end),
      total_count: subscription.total_count ?? TOTAL_COUNT[interval],
      short_url: subscription.short_url ?? null,
      notes: { tide_user_id: userId, tide_plan_id: plan.id },
    });

    if (writeError) {
      // The subscription exists at Razorpay and not here, so nothing could
      // ever verify against it or grant for it. Cancel it rather than leave a
      // mandate nobody on this side knows about — that one would charge.
      try {
        await cancelSubscription(subscription.id, { cancelAtCycleEnd: false });
      } catch (error) {
        console.error('Orphan subscription not cancelled:', String(error));
      }
      return fail(
        'server_error',
        'The subscription could not be recorded. Nothing has been charged.',
        500,
        writeError.message,
      );
    }

    return json({
      subscription_id: subscription.id,
      amount_minor: plan.amount_minor,
      currency: plan.currency,
      key_id: Deno.env.get('RAZORPAY_KEY_ID'),
      plan: plan.id,
      short_url: subscription.short_url ?? null,
      reused: false,
    });
  } catch (error) {
    if (error instanceof RazorpayError) {
      return fail(
        'gateway_error',
        'The payment provider refused to open a subscription.',
        502,
        error.body,
      );
    }
    return fail('server_error', String(error), 500);
  }
});
