// Step 1 · Create the order.
//
// POST { plan: "pro_monthly" | "pro_yearly" }
//   → { order_id, amount_minor, currency, key_id, plan, receipt, contact?, email? }
//
// Called by `SupabaseBillingService.startCheckout`. Everything the checkout
// needs comes back from here, including the public key id — so rotating keys
// is a dashboard change and a secrets change, and not an app release.
//
// **The client does not name a price.** It names a plan id, and the amount is
// read from `billing_plans` inside this function. A request that tries to send
// its own `amount` is not rejected; it is ignored, which is stronger.
//
// **An order is not free to create.** A signed-in account that hammers this
// would leave a trail of open orders at Razorpay, so an order created in the
// last few minutes for the same plan is handed back instead of a new one. That
// also fixes the ordinary case it looks like a guard against: somebody who
// backgrounds the app mid-payment and comes back to the sheet.

import { fail, json, preflight } from '../_shared/http.ts';
import {
  adminClient,
  callerId,
  createOrder,
  RazorpayError,
} from '../_shared/razorpay.ts';

/// How long an unpaid order is reused rather than replaced. Razorpay keeps an
/// order open far longer than this; the window is about the app's behaviour,
/// not theirs.
const REUSE_WINDOW_MINUTES = 12;

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
      .select('id, amount_minor, currency, interval, name')
      .eq('id', planId)
      .eq('active', true)
      .maybeSingle();

    if (planError) {
      return fail('server_error', 'The price list could not be read.', 500, planError.message);
    }
    if (!plan) {
      return fail('unknown_plan', 'That plan is not on sale.', 404);
    }

    // An order this account already has open for this plan, still warm.
    const since = new Date(Date.now() - REUSE_WINDOW_MINUTES * 60_000).toISOString();
    const { data: open } = await db
      .from('payment_orders')
      .select('razorpay_order_id, amount_minor, currency, receipt')
      .eq('user_id', userId)
      .eq('plan_id', plan.id)
      .eq('status', 'created')
      .eq('amount_minor', plan.amount_minor)
      .gte('created_at', since)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (open) {
      return json({
        order_id: open.razorpay_order_id,
        amount_minor: open.amount_minor,
        currency: open.currency,
        key_id: Deno.env.get('RAZORPAY_KEY_ID'),
        plan: plan.id,
        receipt: open.receipt,
        reused: true,
      });
    }

    // Razorpay caps a receipt at 40 characters, which is not enough for a uuid
    // and a prefix, so the account is identified by its first segment. The
    // authoritative link is `notes`, which comes back on every webhook.
    const receipt = `tide_${userId.slice(0, 8)}_${Date.now().toString(36)}`;

    const order = await createOrder({
      amountMinor: plan.amount_minor,
      currency: plan.currency,
      receipt,
      notes: { tide_user_id: userId, tide_plan_id: plan.id },
    });

    const { error: writeError } = await db.from('payment_orders').insert({
      user_id: userId,
      plan_id: plan.id,
      razorpay_order_id: order.id,
      amount_minor: plan.amount_minor,
      currency: plan.currency,
      receipt,
      status: 'created',
      notes: { tide_user_id: userId, tide_plan_id: plan.id },
    });

    if (writeError) {
      // The order exists at Razorpay but not here, so nothing could ever
      // verify against it. Better to refuse now than to hand the app an order
      // id that the verify step will not recognise.
      return fail(
        'server_error',
        'The order could not be recorded. Nothing has been charged.',
        500,
        writeError.message,
      );
    }

    return json({
      order_id: order.id,
      amount_minor: plan.amount_minor,
      currency: plan.currency,
      key_id: Deno.env.get('RAZORPAY_KEY_ID'),
      plan: plan.id,
      receipt,
      reused: false,
    });
  } catch (error) {
    if (error instanceof RazorpayError) {
      return fail(
        'gateway_error',
        'The payment provider refused to open an order.',
        502,
        error.body,
      );
    }
    return fail('server_error', String(error), 500);
  }
});
