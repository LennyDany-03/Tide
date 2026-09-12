// Shared plumbing for Tide's billing functions: CORS, JSON replies, and the
// one place a caller is turned into a user id.

/// The app calls these from Android, iOS and Flutter web. Web is the only one
/// that preflights, and it is the reason this exists at all.
export const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

/// What the app is shown when something goes wrong.
///
/// `code` is the machine-readable half — `lib/services/billing/` switches on
/// it to decide whether to offer a retry, send somebody back to the plan
/// picker, or say the payment is still being confirmed. `message` is the half
/// a person reads. Razorpay's own error object is passed through as `detail`
/// when there is one, because its `description` is usually better written than
/// anything we would invent for a declined card.
export function fail(
  code: string,
  message: string,
  status = 400,
  detail?: unknown,
): Response {
  return json({ error: { code, message, detail: detail ?? null } }, status);
}

export function preflight(req: Request): Response | null {
  return req.method === 'OPTIONS'
    ? new Response('ok', { headers: corsHeaders })
    : null;
}

/// Constant-time comparison of two hex digests.
///
/// Not paranoia for its own sake: `a === b` on a signature leaks, through how
/// long it takes to fail, how many leading characters were right. That is
/// enough to forge a signature given enough attempts, and Razorpay's guide
/// asks for a timing-safe compare by name.
export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/// HMAC-SHA256 of `body` under `secret`, hex encoded — the one primitive both
/// the payment signature and the webhook signature are built from.
export async function hmacSha256Hex(
  secret: string,
  body: string | Uint8Array,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const data = typeof body === 'string' ? new TextEncoder().encode(body) : body;
  const signature = await crypto.subtle.sign('HMAC', key, data as BufferSource);
  return [...new Uint8Array(signature)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

/// Reads an environment variable that the function cannot work without, and
/// says which one is missing rather than failing somewhere further in.
export function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is not set on this project`);
  return value;
}
