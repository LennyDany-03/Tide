# Confirmation email

`confirm_signup.html` is the email Supabase sends when someone creates an
account: Tide's Midnight colours, the logo, and the six-digit code
(`{{ .Token }}`). The app asks for that code on its verify screen. There is
no link in it on purpose — a link only signs in the device that opens it.

## Setting it up

1. **Run** `supabase/auth_setup.sql` in the SQL Editor (safe to re-run). It
   creates the public `email-assets` bucket and teaches `account_status` about
   unconfirmed sign-ups.
2. **Storage → email-assets → Upload** `tide-mark.png` from this folder,
   keeping that exact name. The template loads it from
   `https://tcqsnlydmwwgrfxbwolr.supabase.co/storage/v1/object/public/email-assets/tide-mark.png`.
3. **Authentication → Sign In / Providers → Email**
   - Confirm email: **on**
   - Email OTP Length: **6**
   - Email OTP Expiration: **600** seconds
4. **Authentication → Emails → Templates → Confirm signup**
   - Subject: `Your Tide verification code`
   - Body: paste all of `confirm_signup.html`
5. **Authentication → URL Configuration → Redirect URLs**: remove
   `com.example.tide://login-callback` — nothing uses it now.
6. **Custom SMTP** (Authentication → Emails → SMTP Settings) before real
   users: Supabase's built-in sender allows only a couple of emails an hour.
   Add the SPF/DKIM records your provider gives you, then raise the email
   rate limit under Authentication → Rate Limits.

## Things that must stay in step

- "10 minutes" in the template, `AppConstants.emailCodeLifetimeMinutes`, and
  Email OTP Expiration.
- Six digits: `AppConstants.emailCodeLength` and Email OTP Length.
- The template shows no user-supplied data (no name) on purpose. Anyone can
  sign up with anyone's address, so a name in this email would let a stranger
  put their own words into a genuine Tide message.

## Changing the logo

`flutter test tool/email_assets_test.dart` redraws `tide-mark.png` from the
same painter as the app icon. Upload it again afterwards (Storage caches by
URL for up to an hour).
