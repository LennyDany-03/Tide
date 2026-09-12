// Step 3 · Verify what the device says happened, then grant the period.
//
// POST { razorpay_order_id, razorpay_payment_id, razorpay_signature }
//   → { entitlement: { pro, plan, status, current_period_end, ... } }
//
// POST { razorpay_subscription_id, razorpay_payment_id, razorpay_signature }
//   → { entitlement }            // a mandate just authorised
//
// POST { razorpay_order_id | razorpay_subscription_id,
//        error: { code, description, source, step, reason } }
//   → { entitlement }            // a failed attempt, recorded and nothing else
//
// **Two rails, and the signature is not the same shape on both.** An order is
// signed over `order_id|payment_id`; a subscription is signed over
// `payment_id|subscription_id` — the same two kinds of id, the opposite way
// round. Razorpay says nothing useful when you get it wrong: every
// authorisation simply fails to verify. See `verifySubscriptionSignature`.
//
// The subscription branch is also the one place where a device callback is
// *not* what the flow is built on, even more than usual. A mandate's first
// charge and every charge after it arrive as `subscription.charged` at the
// webhook; this endpoint exists so the person who just authorised one sees Pro
// turn on without waiting, and it grants nothing the webhook would not.
//
// Four checks, in this order, and the order is the point:
//
//   1. **The order belongs to the caller.** Read from `payment_orders` by its
//      Razorpay id, then matched against the JWT's user. Somebody else's
//      order id plus their own token gets nothing.
//   2. **The signature is ours.** HMAC-SHA256 of `order_id|payment_id` under
//      the key secret, compared timing-safely — and against the order id from
//      *our* row, not the one the device sent. The device could send any pair
//      it liked; it cannot sign one.
//   3. **Razorpay agrees.** The payment is fetched from the API and checked:
//      same order, same amount, same currency, and a status of authorized or
//      captured. This is what closes the gap a leaked key secret would open,
//      and what catches an amount that was altered mid-flight.
//   4. **Only then is anything granted**, through `apply_payment`, which is
//      idempotent and races safely against the webhook.
//
// A payment sitting at `authorized` is captured here before granting.
// Authorised is not paid: Razorpay auto-refunds what is never captured, and
// handing somebody a year for money that goes back to them a week later is the
// one failure in this file that costs real money.

import { fail, json, preflight } from '../_shared/http.ts';
import {
  adminClient,
  atTime,
  callerId,
  capturePayment,
  fetchPayment,
  fetchSubscription,
  RazorpayError,
  verifyPaymentSignature,
  verifySubscriptionSignature,
} from '../_shared/razorpay.ts';

Deno.serve(async (req: Request) => {
  const options = preflight(req);
  if (options) return options;

  try {
    const userId = await callerId(req);
    if (!userId) return fail('unauthorised', 'Sign in first.', 401);

    const body = await req.json().catch(() => ({}));
    const orderId = String(body?.razorpay_order_id ?? '');
    const subscriptionId = String(body?.razorpay_subscription_id ?? '');

    const db = adminClient();

    if (subscriptionId) {
      return await verifyMandate(db, {
        userId,
        subscriptionId,
        paymentId: String(body?.razorpay_payment_id ?? ''),
        signature: String(body?.razorpay_signature ?? ''),
        failure: body?.error ?? null,
      });
    }

    if (!orderId) return fail('bad_request', 'No order was named.', 400);

    const { data: order, error: readError } = await db
      .from('payment_orders')
      .select('id, user_id, plan_id, amount_minor, currency, status')
      .eq('razorpay_order_id', orderId)
      .maybeSingle();

    if (readError) {
      return fail('server_error', 'The order could not be read.', 500, readError.message);
    }
    // Deliberately the same answer for "no such order" and "not yours": this
    // endpoint should not confirm that an order id exists.
    if (!order || order.user_id !== userId) {
      return fail('unknown_order', 'That order does not belong to this account.', 404);
    }

    // --- The attempt failed -------------------------------------------------
    // Recorded rather than ignored, because a run of `GATEWAY_ERROR` from one
    // bank is invisible if only successes are written down. Nothing is granted
    // and nothing is revoked: a failed attempt on an order has no bearing on a
    // period already paid for.
    if (body?.error) {
      const detail = body.error ?? {};
      if (order.status !== 'captured') {
        await db
          .from('payment_orders')
          .update({
            status: 'failed',
            failure: {
              code: detail.code ?? null,
              description: detail.description ?? null,
              source: detail.source ?? null,
              step: detail.step ?? null,
              reason: detail.reason ?? null,
            },
          })
          .eq('id', order.id);
      }
      const { data: current } = await db.rpc('entitlement_of', { p_user_id: userId });
      return json({ entitlement: current, applied: false });
    }

    const paymentId = String(body?.razorpay_payment_id ?? '');
    const signature = String(body?.razorpay_signature ?? '');
    if (!paymentId || !signature) {
      return fail('bad_request', 'The payment did not come back complete.', 400);
    }

    // --- 2. The signature ---------------------------------------------------
    const signed = await verifyPaymentSignature({ orderId, paymentId, signature });
    if (!signed) {
      await db
        .from('payment_orders')
        .update({
          status: 'failed',
          failure: { code: 'SIGNATURE_MISMATCH', reason: 'tampered' },
        })
        .eq('id', order.id)
        .neq('status', 'captured');
      return fail('signature_mismatch', 'That payment could not be verified.', 400);
    }

    // --- 3. Razorpay's own record -------------------------------------------
    const payment = await fetchPayment(paymentId);

    if (payment.order_id !== orderId) {
      return fail('payment_mismatch', 'That payment belongs to another order.', 400);
    }
    if (payment.amount !== order.amount_minor || payment.currency !== order.currency) {
      return fail(
        'amount_mismatch',
        'The amount paid does not match the plan.',
        400,
        { paid: payment.amount, expected: order.amount_minor },
      );
    }

    if (payment.status === 'failed') {
      await db
        .from('payment_orders')
        .update({
          status: 'failed',
          method: payment.method ?? null,
          failure: {
            code: payment.error_code ?? null,
            description: payment.error_description ?? null,
            source: payment.error_source ?? null,
            step: payment.error_step ?? null,
            reason: payment.error_reason ?? null,
          },
        })
        .eq('id', order.id);
      return fail(
        'payment_failed',
        payment.error_description ?? 'The payment did not go through.',
        402,
      );
    }

    if (payment.status === 'authorized') {
      // Auto-capture is on for every order this project creates, so reaching
      // here means the dashboard's Payment Capture setting overrode it. Capture
      // now rather than trust it to happen.
      await capturePayment(paymentId, order.amount_minor, order.currency);
    } else if (payment.status !== 'captured') {
      // 'created' — the device came back before the bank did. The webhook will
      // finish it; the app is told to wait rather than told it failed.
      return json({ entitlement: null, applied: false, pending: true });
    }

    // --- 4. Grant ------------------------------------------------------------
    const { data: entitlement, error: grantError } = await db.rpc('apply_payment', {
      p_razorpay_order_id: orderId,
      p_razorpay_payment_id: paymentId,
      p_method: payment.method ?? null,
      p_signature_verified: true,
    });

    if (grantError) {
      // The money is taken and verified; only the grant failed. Say so
      // precisely — the webhook will apply the same payment, so this is
      // recoverable and must not read as a failed payment.
      return fail(
        'grant_failed',
        'Payment received. Your plan is still being applied.',
        500,
        grantError.message,
      );
    }

    return json({ entitlement, applied: true });
  } catch (error) {
    if (error instanceof RazorpayError) {
      return fail('gateway_error', 'The payment provider could not be reached.', 502, error.body);
    }
    return fail('server_error', String(error), 500);
  }
});

/// The subscription rail.
///
/// Same four checks in the same order as the order rail, with one difference
/// that matters: **the amount is not checked here.** There is no order row
/// naming a figure — Razorpay computed the charge from the plan the
/// subscription was created against — so what is verified is that the mandate
/// is ours, that the signature is over our subscription id, and that Razorpay's
/// own record of the subscription says it is authenticated or active. The
/// amount is settled by which Razorpay plan the subscription was opened
/// against, and that id never leaves this project's secrets.
// deno-lint-ignore no-explicit-any
async function verifyMandate(db: any, input: {
  userId: string;
  subscriptionId: string;
  paymentId: string;
  signature: string;
  // deno-lint-ignore no-explicit-any
  failure: any;
}): Promise<Response> {
  const { data: mandate, error: readError } = await db
    .from('billing_mandates')
    .select('razorpay_subscription_id, user_id, plan_id, status')
    .eq('razorpay_subscription_id', input.subscriptionId)
    .maybeSingle();

  if (readError) {
    return fail('server_error', 'The subscription could not be read.', 500, readError.message);
  }
  // Deliberately the same answer for "no such mandate" and "not yours".
  if (!mandate || mandate.user_id !== input.userId) {
    return fail(
      'unknown_subscription',
      'That subscription does not belong to this account.',
      404,
    );
  }

  // --- The authorisation was dismissed or refused ---------------------------
  // Nothing to close: no money was taken and no period was granted. The row is
  // left at 'created' on purpose, which is what lets create-subscription hand
  // the same subscription back when the person comes round to it again —
  // deleting it here would be the bug where dismissing the sheet once locks an
  // account out of subscribing.
  if (input.failure) {
    const { data: current } = await db.rpc('entitlement_of', {
      p_user_id: input.userId,
    });
    return json({ entitlement: current, applied: false });
  }

  if (!input.paymentId || !input.signature) {
    return fail('bad_request', 'The authorisation did not come back complete.', 400);
  }

  // --- The signature, over our subscription id and in the other order ------
  const signed = await verifySubscriptionSignature({
    subscriptionId: mandate.razorpay_subscription_id,
    paymentId: input.paymentId,
    signature: input.signature,
  });
  if (!signed) {
    return fail('signature_mismatch', 'That authorisation could not be verified.', 400);
  }

  // --- Razorpay's own record ------------------------------------------------
  const subscription = await fetchSubscription(mandate.razorpay_subscription_id);
  const live = ['authenticated', 'active'].includes(subscription.status);

  await db
    .from('billing_mandates')
    .update({
      status: subscription.status ?? mandate.status,
      charge_at: atTime(subscription.charge_at),
      current_end: atTime(subscription.current_end),
      paid_count: subscription.paid_count ?? 0,
      auth_payment_id: input.paymentId,
    })
    .eq('razorpay_subscription_id', mandate.razorpay_subscription_id);

  if (!live) {
    // 'created' still, or already over. The mandate is registered as far as
    // the device knows and Razorpay has not caught up, which is the same
    // "wait, do not despair" answer the order rail gives.
    return json({ entitlement: null, applied: false, pending: true });
  }

  // --- Grant ----------------------------------------------------------------
  // The first charge of a subscription is a real payment, and it is fetched
  // rather than assumed: an `authenticated` mandate on some rails is a
  // zero-rupee authorisation with no period behind it yet, and granting a
  // month for that would be granting a month for nothing.
  const payment = await fetchPayment(input.paymentId);
  if (payment.status !== 'captured' && payment.status !== 'authorized') {
    return json({ entitlement: null, applied: false, pending: true });
  }
  if (payment.status === 'authorized') {
    await capturePayment(input.paymentId, payment.amount, payment.currency);
  }

  const { data: entitlement, error: grantError } = await db.rpc(
    'apply_subscription_charge',
    {
      p_razorpay_subscription_id: mandate.razorpay_subscription_id,
      p_razorpay_payment_id: input.paymentId,
      p_amount_minor: payment.amount,
      p_method: payment.method ?? null,
      p_current_end: atTime(subscription.current_end),
      p_charge_at: atTime(subscription.charge_at),
      p_paid_count: subscription.paid_count ?? 1,
    },
  );

  if (grantError) {
    return fail(
      'grant_failed',
      'Payment received. Your plan is still being applied.',
      500,
      grantError.message,
    );
  }

  return json({ entitlement, applied: true });
}
