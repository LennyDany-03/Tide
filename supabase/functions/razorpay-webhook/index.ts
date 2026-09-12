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
//   subscription.authenticated · subscription.activated · subscription.charged
//   subscription.pending · subscription.halted · subscription.cancelled
//   subscription.paused · subscription.resumed · subscription.completed
//
// **A subscription charge arrives twice, under two names, and only one of them
// may grant.** Razorpay creates an order of its own for every debit a mandate
// makes, so `payment.captured` turns up carrying an `order_id` that this
// project never created — and `apply_payment` would raise `no order on this
// project` for it, the handler would 500, and the retry would be swallowed as
// a duplicate by the ledger insert below. Money taken, no period granted, no
// alarm. So the payment cases skip anything with a subscription id on it and
// leave it to `subscription.charged`, which is the delivery that knows which
// mandate it belongs to.

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
  const subscription = pick(event, 'payload.subscription.entity');

  const orderId = String(
    payment?.order_id ?? order?.id ?? refund?.payment_id ?? '',
  );
  const paymentId = String(payment?.id ?? refund?.payment_id ?? '');
  // A payment made by a mandate names it. Present on the `subscription.*`
  // deliveries, and on the `payment.*` ones that belong to a debit.
  const subscriptionId = String(
    subscription?.id ?? payment?.subscription_id ?? '',
  );

  const db = adminClient();

  // The ledger insert *is* the idempotency check: a primary key collision on
  // the delivery id means this event has been handled, and the handler stops
  // before anything is granted. Razorpay retries anything it did not get a 200
  // from, and can send the same event twice unprompted.
  const { error: seen } = await db.from('billing_events').insert({
    id: deliveryId,
    event: name,
    // The subscription id goes in the order column for a mandate delivery:
    // this table is a log to be read by a human when something has gone wrong,
    // and "which thing was this about" is the question it has to answer.
    order_id: orderId || subscriptionId || null,
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
        // A mandate's own debit. Razorpay captures it and tells us again as
        // `subscription.charged`, which is the only case allowed to grant.
        if (subscriptionId) break;
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
        // See the note at the top of the file: this is the delivery that would
        // otherwise try to apply a renewal against an order row that does not
        // exist, fail, and be retried into silence.
        if (subscriptionId) break;
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
        // A failed debit is `subscription.pending`'s business, not a failed
        // order: there is no order of ours to mark, and writing a 'failed'
        // receipt for it would put "Payment failed" in the history of somebody
        // whose card Razorpay is about to retry successfully.
        if (subscriptionId) break;
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

      // --- Auto-pay ---------------------------------------------------------

      // Money arriving on a mandate. **The only case that grants a period on
      // this rail**, and the one the whole flow is built on: by definition
      // nobody was holding the phone when a renewal went through.
      //
      // `apply_subscription_charge` is idempotent on the payment id, so a
      // second delivery of the same charge under a new event id — which the
      // ledger below cannot catch — buys nothing.
      case 'subscription.charged': {
        if (!subscriptionId || !paymentId) break;
        const { error } = await db.rpc('apply_subscription_charge', {
          p_razorpay_subscription_id: subscriptionId,
          p_razorpay_payment_id: paymentId,
          p_razorpay_invoice_id: payment?.invoice_id ?? null,
          p_amount_minor: payment?.amount ?? null,
          p_method: payment?.method ?? null,
          p_current_end: at(subscription?.current_end),
          p_charge_at: at(subscription?.charge_at),
          p_paid_count: subscription?.paid_count ?? null,
        });
        if (error) throw new Error(error.message);
        break;
      }

      // Everything else a subscription does. All of it lands on one function
      // that can change a status and nothing else — see `sync_mandate_state`
      // — which is what makes this list safe to extend without re-reasoning
      // about entitlement every time Razorpay adds an event.
      //
      // `pending` and `halted` are the two worth naming: a debit failed, and
      // the period already paid for keeps running regardless. Taking Pro away
      // from somebody mid-retry is how they end up paying twice.
      case 'subscription.authenticated':
      case 'subscription.activated':
      case 'subscription.pending':
      case 'subscription.halted':
      case 'subscription.paused':
      case 'subscription.resumed':
      case 'subscription.cancelled':
      case 'subscription.completed':
      case 'subscription.updated': {
        if (!subscriptionId) break;
        const { error } = await db.rpc('sync_mandate_state', {
          p_razorpay_subscription_id: subscriptionId,
          // Razorpay's own status rather than one derived from the event name:
          // the two can differ, and the entity is the newer of the two.
          p_status: subscription?.status ?? statusFor(name),
          p_charge_at: at(subscription?.charge_at),
          p_current_end: at(subscription?.current_end),
          p_paid_count: subscription?.paid_count ?? null,
          p_auth_payment_id: paymentId || null,
        });
        // A delivery for a subscription this project has no row for is not an
        // error to retry — it is a mandate created against another
        // environment's database, and retrying it forever achieves nothing.
        if (error && !/no mandate/.test(error.message)) {
          throw new Error(error.message);
        }
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

/// Unix seconds to ISO, for the timestamptz parameters.
function at(seconds: unknown): string | null {
  if (typeof seconds !== 'number' || !Number.isFinite(seconds)) return null;
  return new Date(seconds * 1000).toISOString();
}

/// The status an event name implies, for the rare delivery whose entity does
/// not carry one. `subscription.activated` says 'active' rather than
/// 'activated' — the event names and the status vocabulary are close enough to
/// be confused and are not the same list.
function statusFor(event: string): string {
  switch (event) {
    case 'subscription.activated':
    case 'subscription.resumed':
      return 'active';
    case 'subscription.authenticated':
      return 'authenticated';
    case 'subscription.pending':
      return 'pending';
    case 'subscription.halted':
      return 'halted';
    case 'subscription.paused':
      return 'paused';
    case 'subscription.cancelled':
      return 'cancelled';
    case 'subscription.completed':
      return 'completed';
    default:
      return 'active';
  }
}

async function digest(bytes: Uint8Array): Promise<string> {
  const hash = await crypto.subtle.digest('SHA-256', bytes as BufferSource);
  return [...new Uint8Array(hash)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
    .slice(0, 32);
}
