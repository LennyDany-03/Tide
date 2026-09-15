# Tide

Habits that move like water. This repository holds two things:

- **`product/`** is the Tide app (Flutter). See `product/CLAUDE.md`.
- **The repo root** is the Tide website (Next.js 16): the landing page, the
  thank-you page at `/thanks` and the changelog at `/changelog`.

## Website

```bash
npm install
npm run dev        # http://localhost:3000
npm run build
npm run lint
```

- The version number and download link come from the `version.json`
  attached to the latest GitHub Release (re-checked every 15 minutes, with
  `lib/release-fallback.json` as the offline copy). The site also serves it
  at `/version.json`.
- `/changelog` is rendered from `CHANGELOG.md` at build time.
- The phone screenshots in `public/screens/` are rendered from the real app:
  `cd product && flutter test tool/site_screenshots_test.dart`.

## Releases

Bump the version, write the changelog, merge to `main`. GitHub Actions builds
the signed APK and publishes a GitHub Release with the APK and the manifest
that the app's in-app updater and this site read. Full instructions and one-time setup:
[`TRIGGER.md`](TRIGGER.md).
