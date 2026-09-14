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

- The version number and download link come from `public/version.json`,
  which the release workflow rewrites.
- `/changelog` is rendered from `CHANGELOG.md` at build time.
- The phone screenshots in `public/screens/` are rendered from the real app:
  `cd product && flutter test tool/site_screenshots_test.dart`.

## Releases

Bump the version, write the changelog, merge to `main`. GitHub Actions builds
the signed APK, publishes the GitHub Release and updates the manifest that
the app's in-app updater reads. Full instructions and one-time setup:
[`TRIGGER.md`](TRIGGER.md).
