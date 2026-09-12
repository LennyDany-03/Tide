// Step 3 · Verify what the device says happened, then grant the period.
//
// POST { razorpay_order_id, razorpay_payment_id, razorpay_signature }
//   → { entitlement: { pro, plan, status, current_period_end, ... } }
//
// POST { razorpay_order_id, error: { code, description, source, step, reason } }
//   → { entitlement }            // a failed attempt, recorded and nothing else
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
  callerId,
  capturePayment,
  fetchPayment,
  RazorpayError,
  verifyPaymentSignature,
} from '../_shared/razorpay.ts';

Deno.serve(async (req: Request) => {
  const options = preflight(req);
  if (options) return options;

  try {
    const userId = await callerId(req);
    if (!userId) return fail('unauthorised', 'Sign in first.', 401);

    const body = await req.json().catch(() => ({}));
    const orderId = String(body?.razorpay_order_id ?? '');
    if (!orderId) return fail('bad_request', 'No order was named.', 400);

    const db = adminClient();

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
