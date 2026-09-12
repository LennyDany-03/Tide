// Auto-pay · Stop the mandate.
//
// POST {}  → { entitlement: { pro, status, current_period_end, ... } }
//
// **The only write the app makes that leaves this project.** Everything else
// it can reach is a row in Postgres; this reaches Razorpay, because a standing
// instruction to debit a card lives there and no SQL function can revoke it.
// That is also why `cancel_subscription()` refuses a row with a mandate: a row
// marked cancelled while the instruction still stands is the worst outcome
// available — the app says nothing more will be taken, and the money keeps
// going out every month.
//
// **Razorpay first, our row second**, and never the other way round. A failure
// at their end then leaves nothing claimed here and the person can try again;
// the reverse order would leave somebody believing a debit had been stopped
// when it had not.
//
// `cancel_at_cycle_end` is what keeps the promise the dialog makes: the next
// debit does not happen, and the cycle already paid for runs to its end. This
// is not reversible at Razorpay — there is no un-cancel — which is why the app
// offers "Subscribe again" rather than "Resume" afterwards.
//
// No body, no parameters: whoever holds the token is who is cancelled. There
// is nothing here for a caller to aim at somebody else.

import { fail, json, preflight } from '../_shared/http.ts';
import {
  adminClient,
  atTime,
  callerId,
  cancelSubscription,
  RazorpayError,
} from '../_shared/razorpay.ts';

Deno.serve(async (req: Request) => {
  const options = preflight(req);
  if (options) return options;

  try {
    const userId = await callerId(req);
    if (!userId) return fail('unauthorised', 'Sign in first.', 401);

    const db = adminClient();

    // The mandate this account's plan is actually being paid for by, read from
    // the subscription row rather than by searching the mandate table: an
    // account can hold several dead mandates and the live one is whichever the
    // period points at.
    const { data: plan, error: readError } = await db
      .from('subscriptions')
      .select('mandate_id')
      .eq('user_id', userId)
      .maybeSingle();

    if (readError) {
      return fail('server_error', 'The plan could not be read.', 500, readError.message);
    }

    const mandateId = plan?.mandate_id as string | null | undefined;

    // No mandate: a prepaid period, which the app cancels through the RPC and
    // should never have sent here. Answered rather than refused, so a build
    // that gets the branch wrong still does the right thing.
    if (!mandateId) {
      const { data: entitlement, error } = await db.rpc(
        'cancel_subscription_for',
        { p_user_id: userId },
      );
      if (error) {
        return fail('server_error', 'The plan could not be cancelled.', 500, error.message);
      }
      return json({ entitlement, mandate: null });
    }

    const { data: mandate } = await db
      .from('billing_mandates')
      .select('razorpay_subscription_id, user_id, status')
      .eq('razorpay_subscription_id', mandateId)
      .maybeSingle();

    // Belongs to somebody else: not possible through the read above, and
    // checked anyway because the consequence of being wrong is cancelling a
    // stranger's plan.
    if (mandate && mandate.user_id !== userId) {
      return fail('unknown_mandate', 'That subscription is not on this account.', 404);
    }

    // Written before the call, not after. Razorpay may well succeed and the
    // reply get lost, and a request that was made has to be visible either
    // way — this is the difference between "we have asked" and "they have
    // confirmed", which is exactly what the column is for.
    await db
      .from('billing_mandates')
      .update({ cancel_requested_at: new Date().toISOString() })
      .eq('razorpay_subscription_id', mandateId);

    const alreadyOver = mandate != null &&
      ['cancelled', 'completed', 'expired'].includes(mandate.status);

    if (!alreadyOver) {
      const cancelled = await cancelSubscription(mandateId);
      await db
        .from('billing_mandates')
        .update({
          status: cancelled.status ?? 'cancelled',
          charge_at: atTime(cancelled.charge_at),
          current_end: atTime(cancelled.current_end),
        })
        .eq('razorpay_subscription_id', mandateId);
    }

    // Only now. `subscription.cancelled` will arrive at the webhook and land
    // on `sync_mandate_state`, which writes the same thing — so this is a
    // shortcut for the person watching the screen, not the source of truth.
    const { data: entitlement, error: markError } = await db.rpc(
      'cancel_subscription_for',
      { p_user_id: userId },
    );

    if (markError) {
      // The debit *is* stopped, which is the part that matters and the part
      // that cannot be undone by retrying. Say so precisely: anything that
      // reads as "cancelling failed" invites a second attempt at something
      // already done.
      return fail(
        'mark_failed',
        'Your subscription is cancelled. The plan is still being updated.',
        500,
        markError.message,
      );
    }

    return json({ entitlement, mandate: mandateId });
  } catch (error) {
    if (error instanceof RazorpayError) {
      return fail(
        'gateway_error',
        'The payment provider could not be reached. Nothing has changed — ' +
          'try again in a moment.',
        502,
        error.body,
      );
    }
    return fail('server_error', String(error), 500);
  }
});
