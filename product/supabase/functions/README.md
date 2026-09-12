# Tide · billing functions

Five Deno Edge Functions. Between them they are the only code on the project
that holds a Razorpay secret, and the only code allowed to write
`payment_orders`, `billing_mandates` or `subscriptions`.

| Function                        | Who calls it                     | JWT |
| ------------------------------- | -------------------------------- | --- |
| `razorpay-create-order`         | the app, before a one-off payment| yes |
| `razorpay-create-subscription`  | the app, before subscribing      | yes |
| `razorpay-verify-payment`       | the app, after either checkout   | yes |
| `razorpay-cancel-subscription`  | the app, to stop a mandate       | yes |
| `razorpay-webhook`              | Razorpay                         | no  |

**Two rails, and they are not interchangeable.** A plan whose `billing_mode` is
`auto` is bought as a Razorpay *Subscription* — a mandate that debits on its
own — and a plan marked `one_time` is bought as an *order*, one period and then
nothing. Both grant through the same period arithmetic in SQL
(`extend_period`), but they differ in every step above it: a different create
function, a different signature to check, a different set of webhook events,
and a cancel that has to reach Razorpay rather than write a row.

Both `pro_monthly` and `pro_yearly` are `auto`. The order rail is kept because
every account from before auto-pay holds a prepaid period, and those still have
to renew, cancel and resume.

The webhook is deployed with JWT verification off because Razorpay does not
hold a Supabase token. It is not unauthenticated: the HMAC-SHA256 signature
over the raw body is checked before the body is parsed.

## Before deploying

Run `supabase/billing_setup.sql` in the SQL editor. The functions call
`apply_payment`, `apply_subscription_charge`, `sync_mandate_state`,
`revoke_payment` and `cancel_subscription_for`, which that script installs. It
is written to be pasted again over a project that already has an earlier
version — section 0 adds the columns auto-pay needed.

For the subscription rail you also need **Plans** at Razorpay, because a
subscription is opened against one. Dashboard → Subscriptions → Plans → New
Plan, one per Tide plan:

| Plan name         | Billing frequency | Amount | Tide plan     |
| ----------------- | ----------------- | ------ | ------------- |
| Tide Pro Monthly  | Every 1 Month(s)  | 100.00 | `pro_monthly` |
| Tide Pro Yearly   | Every 1 Year(s)   | 499.00 | `pro_yearly`  |

Razorpay says it plainly on that form: **billing amount and frequency cannot be
changed later.** A price change means a new plan id, and every mandate already
standing keeps charging the old figure until its holder re-subscribes.

The frequency is a *calendar* month or year, which is 28 to 31 days rather than
the flat 30 in `billing_plans.period_days`. That is deliberate and is why
`apply_subscription_charge` takes the period end from Razorpay's own
`current_end` instead of counting days — a date computed here would drift off
the date the money actually moves, and Pro would flicker off for a day in every
31-day month.

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
  RAZORPAY_WEBHOOK_SECRET=<32+ random characters you choose> \
  RAZORPAY_PLAN_PRO_MONTHLY=plan_xxxxxxxxxxxxxx \
  RAZORPAY_PLAN_PRO_YEARLY=plan_xxxxxxxxxxxxxx
```

```powershell
# PowerShell. A trailing backslash is not a continuation here — it is passed
# through as part of the argument, and the secret is stored with it attached.
# Keep it to one line, or wrap with a backtick.
supabase secrets set RAZORPAY_KEY_ID=rzp_test_xxxx RAZORPAY_KEY_SECRET=xxxx RAZORPAY_WEBHOOK_SECRET=xxxx
```

`supabase secrets list` prints the names and a digest of each value — enough to
confirm all five landed, without printing them back.

**Why the plan ids are secrets and not table columns.** They are
environment-scoped exactly the way the key id is: the plan you create in test
mode has a different id from the one you create in live mode, and
`billing_plans` has one row per plan with nowhere to put both. Keeping them here
means switching environments is a secrets change rather than a data migration.
`razorpay-create-subscription` looks up `RAZORPAY_PLAN_` + the Tide plan id in
upper case, so a plan added later needs a secret of the matching name and no
code change.

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
supabase functions deploy razorpay-create-subscription
supabase functions deploy razorpay-verify-payment
supabase functions deploy razorpay-cancel-subscription
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
  - **Subscription events** — the auto-pay rail:
    - `subscription.charged` — **the one that grants a renewal.** Nothing else
      on this rail grants anything
    - `subscription.authenticated`, `subscription.activated` — the mandate is
      registered
    - `subscription.pending` — a debit failed and Razorpay is retrying
    - `subscription.halted` — it has stopped retrying
    - `subscription.cancelled`, `subscription.completed`
    - `subscription.paused`, `subscription.resumed`

> **`payment.captured` fires for a renewal too, and must not grant it.** Every
> debit a mandate makes gets an order of Razorpay's own, so that delivery
> arrives with an `order_id` this project never created. Handing it to
> `apply_payment` raises `no order on this project`, the handler returns 500,
> and Razorpay's retry is then swallowed as a duplicate by the event ledger:
> money taken, no period granted, nothing raised. The payment cases in
> `razorpay-webhook` skip any delivery carrying a subscription id for exactly
> this reason. If you rewrite that file, keep the guard.

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

## Checking the subscription rail works

Test mode cannot fast-forward a billing cycle, so this splits into the part you
can click through and the part you have to replay by hand.

**1. Authorising a mandate.** Run the app against the test keys and buy a plan.
Razorpay's test-mode e-mandate cards are in their docs under Subscriptions;
UPI AutoPay does not appear on an emulator (see below). Afterwards:

- `billing_mandates` has one row, `status` `authenticated` or `active`, with a
  `charge_at` in the future.
- `subscriptions` has `mandate_id` set and a period running.
- `payment_orders` has a row with `kind = 'subscription'`.
- The app says **renews**, not *until*, and offers Cancel rather than Extend.

If the mandate row stays at `created`, the authorisation never completed — the
subscription is still openable and `razorpay-create-subscription` will hand the
same one back when you try again. That reuse is deliberate: without it,
dismissing the sheet once would lock the account out of subscribing.

**2. A renewal.** Take the `subscription.charged` body from Razorpay's docs,
put your own `subscription.entity.id` and a fresh `payment.entity.id` into it,
and POST it to the webhook with a correct `X-Razorpay-Signature` (HMAC-SHA256
of the **raw body** under `RAZORPAY_WEBHOOK_SECRET`). Then check:

- `current_period_end` moved forward to the new `current_end` plus two days of
  slack — not by a flat 30 days.
- A second POST of the *same* payment id changes nothing. Razorpay replays
  webhooks, and `apply_subscription_charge` is keyed on the payment id rather
  than on the delivery id for precisely that reason.

**3. A failed debit.** Replay `subscription.pending`. `subscriptions.status`
becomes `past_due`, **`current_period_end` does not move**, and the app still
draws Pro with a line saying the renewal did not go through. Then
`subscription.halted`: same period, `autoRenews` false. If either of these ever
takes Pro away, the bug is in `sync_mandate_state` — check that no SET list in
it names a period column; `test/billing_sql_test.dart` asserts that too.

**4. Cancelling.** Tap Cancel in the app. In order:

- `billing_mandates.cancel_requested_at` is set *before* Razorpay is called,
- the subscription at Razorpay goes to `cancelled` with the current cycle still
  running (`cancel_at_cycle_end`),
- `subscriptions.status` becomes `cancelled` and the period is unchanged,
- the app keeps Pro to the end of the period and now offers **Subscribe again**
  rather than Resume.

That last point is not a UI preference. Razorpay has no un-cancel, so there is
nothing to resume; `resume_subscription()` refuses a row with a `mandate_id`
and the app turns that into a fresh checkout.

## Local

```bash
supabase functions serve --env-file supabase/functions/.env.local
```

`.env.local` is git-ignored and holds the same three secrets. Razorpay cannot
reach localhost, so test the webhook with `ngrok` and a second webhook entry,
or by replaying a captured body with the signature header set by hand.
