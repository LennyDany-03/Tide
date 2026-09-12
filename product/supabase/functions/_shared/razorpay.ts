// The Razorpay REST client, and the two Supabase clients the billing
// functions use.
//
// **Where the secret lives.** `RAZORPAY_KEY_SECRET` is read here and nowhere
// else in this repository. It is set once with
//
//   supabase secrets set RAZORPAY_KEY_SECRET=...
//
// and it never reaches the app, `.env`, or a build. The app only ever holds
// `RAZORPAY_KEY_ID`, which is public by design — it names the merchant the
// way a Supabase publishable key names a project.

import { hmacSha256Hex, requireEnv, timingSafeEqual } from './http.ts';
import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';

const API = 'https://api.razorpay.com/v1';

export interface RazorpayOrder {
  id: string;
  amount: number;
  currency: string;
  receipt?: string;
  status: string;
}

export interface RazorpaySubscription {
  id: string;
  plan_id: string;
  /// `created` · `authenticated` · `active` · `pending` · `halted` ·
  /// `paused` · `cancelled` · `completed` · `expired`
  status: string;
  /// Unix seconds. `charge_at` is the next debit; `current_end` is the end of
  /// the cycle that has been paid for — the date entitlement follows, because
  /// Razorpay owns this calendar and a date computed here would drift off the
  /// one the money actually moves on.
  charge_at?: number | null;
  current_start?: number | null;
  current_end?: number | null;
  paid_count?: number;
  total_count?: number;
  /// The hosted authorisation page. The only way to rescue a mandate the app
  /// failed to finish registering.
  short_url?: string | null;
  notes?: Record<string, string>;
}

export interface RazorpayPayment {
  id: string;
  order_id: string | null;
  amount: number;
  currency: string;
  /// `created` · `authorized` · `captured` · `refunded` · `failed`
  status: string;
  method?: string;
  error_code?: string | null;
  error_description?: string | null;
  error_source?: string | null;
  error_step?: string | null;
  error_reason?: string | null;
}

export class RazorpayError extends Error {
  constructor(readonly status: number, readonly body: unknown) {
    super(`Razorpay replied ${status}`);
  }
}

function auth(): string {
  const id = requireEnv('RAZORPAY_KEY_ID');
  const secret = requireEnv('RAZORPAY_KEY_SECRET');
  return `Basic ${btoa(`${id}:${secret}`)}`;
}

async function call<T>(
  path: string,
  init: RequestInit & { body?: string } = {},
): Promise<T> {
  const response = await fetch(`${API}${path}`, {
    ...init,
    headers: {
      Authorization: auth(),
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
  });
  const body = await response.json().catch(() => null);
  if (!response.ok) throw new RazorpayError(response.status, body);
  return body as T;
}

/// Step 1 of the flow. `notes` carry our own ids back on every webhook, which
/// is what lets a delivery be tied to an account without a lookup.
export function createOrder(input: {
  amountMinor: number;
  currency: string;
  receipt: string;
  notes: Record<string, string>;
}): Promise<RazorpayOrder> {
  return call<RazorpayOrder>('/orders', {
    method: 'POST',
    // Exactly the fields the Orders API documents, and no more: Razorpay
    // rejects an unrecognised field outright, so a helpful-looking extra
    // (`payment_capture`, which belongs to the older payment-level API) fails
    // every order on the project rather than being ignored.
    //
    // Capture is therefore not arranged here. It is arranged three ways, all
    // of which have to be in place because an authorised-but-uncaptured
    // payment is auto-refunded and is the one failure in this integration
    // that costs real money:
    //   1. Dashboard → Account & Settings → Payment Capture, set to
    //      automatic — see supabase/functions/README.md.
    //   2. razorpay-verify-payment captures an `authorized` payment itself
    //      before granting anything.
    //   3. razorpay-webhook does the same on `payment.authorized`, for the
    //      payments the device never came back to report.
    body: JSON.stringify({
      amount: input.amountMinor,
      currency: input.currency,
      receipt: input.receipt.slice(0, 40),
      notes: input.notes,
    }),
  });
}

/// Auto-pay, step 1. The Razorpay plan id is *not* sent by the app and is not
/// in `billing_plans` either: plan ids differ between test mode and live, the
/// same way the key id does, so they live in this function's own secrets.
///
/// `total_count` is required by the API — there is no "until cancelled" — so it
/// is a number large enough to be one in practice. `customer_notify: 1` hands
/// Razorpay the pre-debit notification, which is not optional under RBI's
/// e-mandate rules and is not something this project should be reimplementing.
export function createSubscription(input: {
  planId: string;
  totalCount: number;
  notes: Record<string, string>;
}): Promise<RazorpaySubscription> {
  return call<RazorpaySubscription>('/subscriptions', {
    method: 'POST',
    body: JSON.stringify({
      plan_id: input.planId,
      total_count: input.totalCount,
      customer_notify: 1,
      notes: input.notes,
    }),
  });
}

export function fetchSubscription(id: string): Promise<RazorpaySubscription> {
  return call<RazorpaySubscription>(
    `/subscriptions/${encodeURIComponent(id)}`,
  );
}

/// **Not reversible.** Razorpay treats a cancelled subscription as finished and
/// offers no un-cancel, which is why the app's Resume button does not exist for
/// a mandate and why `resume_subscription()` refuses one.
///
/// `cancelAtCycleEnd` is the default here on purpose: it stops the next debit
/// and leaves the cycle already paid for running, which is exactly the promise
/// the cancel dialog makes. Cancelling immediately would end a period somebody
/// has paid for and produce a refund request.
export function cancelSubscription(
  id: string,
  { cancelAtCycleEnd = true }: { cancelAtCycleEnd?: boolean } = {},
): Promise<RazorpaySubscription> {
  return call<RazorpaySubscription>(
    `/subscriptions/${encodeURIComponent(id)}/cancel`,
    {
      method: 'POST',
      body: JSON.stringify({ cancel_at_cycle_end: cancelAtCycleEnd ? 1 : 0 }),
    },
  );
}

export function fetchPayment(paymentId: string): Promise<RazorpayPayment> {
  return call<RazorpayPayment>(`/payments/${encodeURIComponent(paymentId)}`);
}

/// Only reached when auto-capture did not fire — a project whose Payment
/// Capture setting was changed in the dashboard, or a Late Auth arriving after
/// the order timed out. Capturing an already-captured payment is an error at
/// Razorpay's end, so the caller checks the status first.
export function capturePayment(
  paymentId: string,
  amountMinor: number,
  currency: string,
): Promise<RazorpayPayment> {
  return call<RazorpayPayment>(
    `/payments/${encodeURIComponent(paymentId)}/capture`,
    { method: 'POST', body: JSON.stringify({ amount: amountMinor, currency }) },
  );
}

/// The checkout signature: HMAC-SHA256 of `order_id|payment_id`, signed with
/// the key secret.
///
/// `orderId` must be the one read from `payment_orders`, never the one the
/// device sent. That is the difference between proving a payment happened and
/// letting somebody prove their own claim about it.
export async function verifyPaymentSignature(input: {
  orderId: string;
  paymentId: string;
  signature: string;
}): Promise<boolean> {
  const expected = await hmacSha256Hex(
    requireEnv('RAZORPAY_KEY_SECRET'),
    `${input.orderId}|${input.paymentId}`,
  );
  return timingSafeEqual(expected, input.signature.toLowerCase());
}

/// The subscription signature — and **the field order is reversed** from
/// [verifyPaymentSignature]. An order is signed over `order_id|payment_id`; a
/// subscription is signed over `payment_id|subscription_id`. Same two kinds of
/// id, opposite order, and no error message from Razorpay that says so: a
/// mandate integration that reuses the order helper simply rejects every
/// authorisation it is ever sent.
///
/// `subscriptionId` must be the one read from `billing_mandates`, never the one
/// the device sent, for the same reason the order flow insists on that: it is
/// the difference between proving a payment happened and letting somebody prove
/// their own claim about it.
export async function verifySubscriptionSignature(input: {
  subscriptionId: string;
  paymentId: string;
  signature: string;
}): Promise<boolean> {
  const expected = await hmacSha256Hex(
    requireEnv('RAZORPAY_KEY_SECRET'),
    `${input.paymentId}|${input.subscriptionId}`,
  );
  return timingSafeEqual(expected, input.signature.toLowerCase());
}

/// Unix seconds to an ISO string, or null. Razorpay sends every date as a
/// number of seconds and Postgres wants a timestamptz.
export function atTime(seconds: number | null | undefined): string | null {
  if (typeof seconds !== 'number' || !Number.isFinite(seconds)) return null;
  return new Date(seconds * 1000).toISOString();
}

/// The webhook signature: HMAC-SHA256 of the **raw** request body, signed with
/// the webhook secret — which is a different secret from the key secret, set
/// separately in Dashboard → Webhooks.
///
/// Raw body, not the parsed JSON re-stringified. `JSON.parse` followed by
/// `JSON.stringify` reorders keys and drops whitespace, and the digest of that
/// will never match. It is the single most common reason a webhook
/// integration silently rejects every delivery.
export async function verifyWebhookSignature(
  rawBody: Uint8Array,
  signature: string,
): Promise<boolean> {
  const expected = await hmacSha256Hex(
    requireEnv('RAZORPAY_WEBHOOK_SECRET'),
    rawBody,
  );
  return timingSafeEqual(expected, signature.toLowerCase());
}

/// The service-role client: bypasses RLS, and is the only thing on the project
/// allowed to write `payment_orders` and `subscriptions`.
export function adminClient(): SupabaseClient {
  return createClient(
    requireEnv('SUPABASE_URL'),
    requireEnv('SUPABASE_SERVICE_ROLE_KEY'),
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}

/// Who is calling, according to their own access token.
///
/// The token is verified by Supabase rather than decoded here, so an expired
/// or forged one resolves to null and the function refuses. Nothing else in
/// the request is trusted to say who the caller is — not a body field, not a
/// header.
export async function callerId(req: Request): Promise<string | null> {
  const header = req.headers.get('Authorization') ?? '';
  if (!header.toLowerCase().startsWith('bearer ')) return null;

  const client = createClient(
    requireEnv('SUPABASE_URL'),
    requireEnv('SUPABASE_ANON_KEY'),
    {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: header } },
    },
  );
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) return null;
  return data.user.id;
}
