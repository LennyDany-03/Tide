# Tide · billing functions

Three Deno Edge Functions. Between them they are the only code on the project
that holds a Razorpay secret, and the only code allowed to write
`payment_orders` or `subscriptions`.

| Function                 | Who calls it                | JWT  |
| ------------------------ | --------------------------- | ---- |
| `razorpay-create-order`  | the app, before checkout    | yes  |
| `razorpay-verify-payment`| the app, after checkout     | yes  |
| `razorpay-webhook`       | Razorpay                    | no   |

The webhook is deployed with JWT verification off because Razorpay does not
hold a Supabase token. It is not unauthenticated: the HMAC-SHA256 signature
over the raw body is checked before the body is parsed.

## Before deploying

Run `supabase/billing_setup.sql` in the SQL editor. The functions call
`apply_payment` and `revoke_payment`, which that script installs.

## Installing the CLI

Not available as a global npm install — the package refuses one. On Windows,
either take the binary from [the releases page](https://github.com/supabase/cli/releases)
(`supabase_<version>_windows_amd64.zip`) and put it on your PATH, or use Scoop:

```bash
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

macOS and Linux: `brew install supabase/tap/supabase`.

Docker is **not** needed for anything in this file. `secrets set` and
`functions deploy` talk to the hosted project over its API; only
`supabase start`, which runs a whole local stack, wants Docker.

## Secrets

```bash
supabase login
supabase link --project-ref <your-project-ref>
```

Then set the three secrets. The shells differ on how a command wraps, so this
is written twice rather than left to be discovered:

```bash
# bash / zsh
supabase secrets set \
  RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxx \
  RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxxxxxxxxxx \
  RAZORPAY_WEBHOOK_SECRET=<32+ random characters you choose>
```

```powershell
# PowerShell. A trailing backslash is not a continuation here — it is passed
# through as part of the argument, and the secret is stored with it attached.
# Keep it to one line, or wrap with a backtick.
supabase secrets set RAZORPAY_KEY_ID=rzp_test_xxxx RAZORPAY_KEY_SECRET=xxxx RAZORPAY_WEBHOOK_SECRET=xxxx
```

`supabase secrets list` prints the names and a digest of each value — enough to
confirm all three landed, without printing them back.

`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are
injected by the platform — do not set them.

The **key secret** is the one from Razorpay → Account & Settings → API Keys,
next to the key id. The **webhook secret** is not issued by Razorpay: you
invent it here and type the same string into the webhook form below. Thirty-two
characters or more.

> The key secret must never appear in `.env`, in `lib/`, in a commit, or in a
> chat window. If it has been anywhere but this command, regenerate the key
> pair in the Razorpay dashboard before going live — and before any real money
> is involved, since a leaked secret is enough to forge a payment signature.

## Deploy

```bash
supabase functions deploy razorpay-create-order
supabase functions deploy razorpay-verify-payment
supabase functions deploy razorpay-webhook --no-verify-jwt
```

## The webhook

Razorpay Dashboard → **Account & Settings → Webhooks → Add New Webhook**

- **URL** `https://<project-ref>.supabase.co/functions/v1/razorpay-webhook`
- **Secret** the `RAZORPAY_WEBHOOK_SECRET` you set above
- **Active events**
  - `payment.captured` — the one that grants the period
  - `order.paid`
  - `payment.authorized` — captures anything auto-capture missed
  - `payment.failed`
  - `refund.created`, `refund.processed` — these take it back
  - `payment.dispute.created`

## Payment capture

Dashboard → **Account & Settings → Payment Capture** → **Automatic**.

Do this before taking a live payment. An authorised payment is not money in
your account, and Razorpay auto-refunds anything left uncaptured — so a missed
capture hands somebody a year of Pro for money that returns to them a week
later, silently.

Two belts behind that brace, because it is the one failure here that costs real
money: `razorpay-verify-payment` captures an `authorized` payment itself before
granting anything, and `razorpay-webhook` does the same on `payment.authorized`
for the payments the app never came back to report.

Set the webhook up in **Test Mode first**, then again in Live Mode when you go
live. They are two separate lists, and a live payment against a test webhook
reaches nothing.

## Checking it works

With the app running against a test key:

1. Buy a plan with test card `4111 1111 1111 1111`, any future expiry, any CVV.
   (Or UPI `success@razorpay`.)
2. `select * from payment_orders order by created_at desc limit 1;` — status
   `captured`, `verified_at` set.
3. `select * from subscriptions;` — `status` `active`, `current_period_end`
   30 or 365 days out.
4. `select event, handled from billing_events order by received_at desc;` — the
   webhook arrived and was handled.
5. `select public.entitlement();` while signed in as that user — `"pro": true`.

To prove the webhook alone is enough, kill the app between paying and the
verify call returning. The subscription is still granted, and the app turns Pro
through the `billing:<user id>` broadcast the moment it reconnects.

To prove idempotency, replay a delivery from Razorpay → Webhooks → the
delivery's **Resend**. `billing_events` gains nothing, `subscriptions` does not
move, and the reply is `{"ok":true,"duplicate":true}`.

## Local

```bash
supabase functions serve --env-file supabase/functions/.env.local
```

`.env.local` is git-ignored and holds the same three secrets. Razorpay cannot
reach localhost, so test the webhook with `ngrok` and a second webhook entry,
or by replaying a captured body with the signature header set by hand.
