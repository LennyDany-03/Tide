// Step 4 · The source of truth.
//
// POST from Razorpay, with `X-Razorpay-Signature` over the raw body.
//
// The verify call in step 3 depends on the app being alive and connected when
// the payment lands. It often is not: the person swipes the app away on the
// bank's OTP page, the phone goes into a tunnel, UPI takes ninety seconds and
// the sheet was closed at sixty. This function does not depend on any of that,
// which is why entitlement is granted here as well and why this — not the
// device's callback — is what the flow is actually built on.
//
// Deploy with JWT verification off; Razorpay does not hold a Supabase token:
//
//   supabase functions deploy razorpay-webhook --no-verify-jwt
//
// It is not unauthenticated. The signature over the raw body is the
// authentication, and it is checked before the body is parsed.
//
// Subscribe in Dashboard → Account & Settings → Webhooks:
//   payment.authorized · payment.captured · payment.failed · order.paid
//   refund.processed · refund.created · payment.dispute.created

import { fail, json, preflight } from '../_shared/http.ts';
import {
  adminClient,
  capturePayment,
  verifyWebhookSignature,
} from '../_shared/razorpay.ts';

Deno.serve(async (req: Request) => {
  const options = preflight(req);
  if (options) return options;

  // The raw bytes, before anything parses them. Re-stringifying parsed JSON
  // reorders keys and drops whitespace, and its digest will never match — the
  // single most common reason a webhook integration quietly rejects every
  // delivery it is sent.
  const raw = new Uint8Array(await req.arrayBuffer());
  const signature = req.headers.get('x-razorpay-signature') ?? '';

  if (!signature || !(await verifyWebhookSignature(raw, signature))) {
    return fail('invalid_signature', 'Signature mismatch.', 400);
  }

  let event: Record<string, unknown>;
  try {
    event = JSON.parse(new TextDecoder().decode(raw));
  } catch {
    return fail('bad_request', 'Body is not JSON.', 400);
  }

  const name = String(event.event ?? '');
  // Razorpay's own delivery id. Falling back to a digest of the body keeps
  // idempotency working if the header is ever absent, since the same event
  // replayed is the same bytes.
  const deliveryId =
    req.headers.get('x-razorpay-event-id') ??
    `${name}:${await digest(raw)}`;

  const payment = pick(event, 'payload.payment.entity');
  const order = pick(event, 'payload.order.entity');
  const refund = pick(event, 'payload.refund.entity');

  const orderId = String(
    payment?.order_id ?? order?.id ?? refund?.payment_id ?? '',
  );
  const paymentId = String(payment?.id ?? refund?.payment_id ?? '');

  const db = adminClient();

  // The ledger insert *is* the idempotency check: a primary key collision on
  // the delivery id means this event has been handled, and the handler stops
  // before anything is granted. Razorpay retries anything it did not get a 200
  // from, and can send the same event twice unprompted.
  const { error: seen } = await db.from('billing_events').insert({
    id: deliveryId,
    event: name,
    order_id: orderId || null,
    payment_id: paymentId || null,
    payload: event,
  });

  if (seen) {
    // 200, not an error. Telling Razorpay a duplicate failed makes it retry
    // the duplicate.
    return json({ ok: true, duplicate: true });
  }

  try {
    switch (name) {
      // Authorised is not paid. Razorpay auto-refunds a payment that is never
      // captured, so leaving one would hand somebody a year for money that
      // goes back to them a week later. Auto-capture should already have
      // fired; this is here because "should" is not good enough when the
      // failure costs real money and is silent for days.
      case 'payment.authorized': {
        if (!orderId || !paymentId) break;
        const { data: row } = await db
          .from('payment_orders')
          .select('amount_minor, currency, status')
          .eq('razorpay_order_id', orderId)
          .maybeSingle();
        if (!row || row.status === 'captured') break;
        await capturePayment(paymentId, row.amount_minor, row.currency);
        // Nothing is granted here. Capturing raises `payment.captured`, which
        // arrives as its own delivery and goes through apply_payment below —
        // so a period has exactly one way in rather than two.
        break;
      }

      // Money confirmed. Both of these mean the same thing for a one-payment
      // order, and Razorpay sends both, so both grant — `apply_payment` makes
      // the second one a no-op.
      case 'payment.captured':
      case 'order.paid': {
        if (!orderId || !paymentId) break;
        const { error } = await db.rpc('apply_payment', {
          p_razorpay_order_id: orderId,
          p_razorpay_payment_id: paymentId,
          p_method: payment?.method ?? null,
          // The webhook signature proves the *delivery*; it is not the
          // checkout signature over order|payment. Only step 3 sets this.
          p_signature_verified: false,
        });
        if (error) throw new Error(error.message);
        break;
      }

      case 'payment.failed': {
        if (!orderId) break;
        await db
          .from('payment_orders')
          .update({
            status: 'failed',
            method: payment?.method ?? null,
            failure: {
              code: payment?.error_code ?? null,
              description: payment?.error_description ?? null,
              source: payment?.error_source ?? null,
              step: payment?.error_step ?? null,
              reason: payment?.error_reason ?? null,
            },
          })
          .eq('razorpay_order_id', orderId)
          .neq('status', 'captured');
        break;
      }

      // Money going back. Access goes with it: `revoke_payment` ends the
      // period this order paid for, and leaves alone any period bought since.
      case 'refund.created':
      case 'refund.processed': {
        if (!orderId) break;
        const { error } = await db.rpc('revoke_payment', {
          p_razorpay_order_id: orderId,
          p_reason: name,
        });
        if (error) throw new Error(error.message);
        break;
      }

      // A chargeback is not a refund yet — the bank is asking, and the money
      // may come back or may not. Access is left alone and the dispute is
      // written down; taking Pro away from somebody whose bank later finds in
      // our favour would be the wrong way round.
      case 'payment.dispute.created': {
        if (!orderId) break;
        await db
          .from('payment_orders')
          .update({ failure: { reason: 'dispute_created', at: new Date().toISOString() } })
          .eq('razorpay_order_id', orderId);
        break;
      }
    }

    await db.from('billing_events').update({ handled: true }).eq('id', deliveryId);
    return json({ ok: true });
  } catch (error) {
    // The delivery is kept with its error so it can be read and replayed by
    // hand. A 500 makes Razorpay retry, which is what should happen when the
    // database was the thing that failed.
    await db
      .from('billing_events')
      .update({ error: String(error) })
      .eq('id', deliveryId);
    return fail('handler_failed', String(error), 500);
  }
});

// deno-lint-ignore no-explicit-any
function pick(source: any, path: string): any {
  return path.split('.').reduce((node, key) => node?.[key], source) ?? null;
}

async function digest(bytes: Uint8Array): Promise<string> {
  const hash = await crypto.subtle.digest('SHA-256', bytes as BufferSource);
  return [...new Uint8Array(hash)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
    .slice(0, 32);
}
