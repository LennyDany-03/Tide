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
