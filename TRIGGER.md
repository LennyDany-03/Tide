# How to release a new version of Tide

A release happens when **the version in `product/pubspec.yaml` changes and that
change reaches `main` with CI green**. Nothing else triggers one: ordinary
pushes run the checks and stop there.

```
push / PR ─► CI (.github/workflows/ci.yml)
               ├─ Flutter app: analyze + test      (when product/ changed)
               ├─ Website: lint + build            (when anything else changed)
               └─ Release notes: changelog check   (when the version or CHANGELOG changed)

CI green on main ─► Release (.github/workflows/release.yml)
               ├─ tag vX.Y.Z already exists?  ─► stop, nothing to do
               ├─ CHANGELOG.md has notes for X.Y.Z?  (fails if not)
               ├─ build a signed release APK
               ├─ GitHub Release vX.Y.Z  + tide-X.Y.Z.apk
               └─ public/version.json updated and committed to main
                        │
                        ├─► website shows the new version and changelog
                        └─► installed apps see the update and install it
```

## Releasing, step by step

**1. Collect notes while you work.** Add lines under `## [Unreleased]` in
`CHANGELOG.md` as changes land. Write them for people using the app.

```md
## [Unreleased]

### Added

- A Sunday recap widget.

### Fixed

- Reminders no longer fire twice after a restart.
```

**2. Bump the version.** From the repo root:

```bash
npm run release:patch   # 1.0.0 -> 1.0.1   bug fixes
npm run release:minor   # 1.0.0 -> 1.1.0   new features
npm run release:major   # 1.0.0 -> 2.0.0   big or breaking changes
```

This does two things:

- `product/pubspec.yaml`: `version: 1.0.0+1` becomes `version: 1.1.0+2`
  (the `+N` build number always goes up by one, which Android requires).
- `CHANGELOG.md`: everything under `[Unreleased]` moves into a new
  `## [1.1.0] - <today>` section. If `[Unreleased]` was empty you get a
  placeholder line; replace it, because CI fails on the placeholder.

You can also edit both files by hand. The rules are the same: a higher
`X.Y.Z`, a higher `+N`, and a dated `## [X.Y.Z] - YYYY-MM-DD` section with at
least one `- ` entry.

**3. Check it locally (optional).**

```bash
node scripts/release.mjs check      # version has finished release notes
node scripts/release.mjs notes      # print what the GitHub Release will say
```

**4. Merge to `main`.** Commit, push your branch, open a pull request, merge
it. (Pushing straight to `main` works too.) CI runs; when it passes, the
Release workflow starts by itself. Watch it under **Actions → Release**.

**5. Done.** When it finishes:

- **Releases** on GitHub has `vX.Y.Z` with `tide-X.Y.Z.apk` and its SHA-256.
- `public/version.json` on `main` points at that APK. If the website is
  deployed from `main` (Vercel does this on every push), it redeploys and
  shows the new version, and the thank-you page links to the real APK.
- Installed apps find the update on their next launch (or when reopened
  after 6 hours), show "Tide X.Y.Z is ready" once, and keep it under
  **Settings → App updates** after that.

## Releasing by hand

**Actions → Release → Run workflow** runs the same pipeline on the current
`main` without waiting for CI. It still skips a version that is already
tagged, so it is safe to press twice.

## Forcing everyone to update

Edit `minSupportedVersion` in `public/version.json` (for example to `1.1.0`)
and commit it. Installs older than that see an update panel they cannot
dismiss. The release workflow keeps whatever value is there.

## One-time setup

Do this before the first release. Without the signing secrets the Release
workflow stops with an error rather than publishing an APK no one could
update from.

### 1. Create the release key (once, ever)

Every release must be signed with the **same** key. Android refuses to install
an update signed with a different one, so if this key is lost, every existing
user has to uninstall and reinstall. Back it up somewhere safe.

```bash
keytool -genkeypair -v -keystore tide-release.jks -alias tide \
  -keyalg RSA -keysize 4096 -validity 10000
```

Never commit the `.jks` file.

### 2. Add repository secrets

**Settings → Secrets and variables → Actions → New repository secret**

| Secret                      | Value                                                        |
| --------------------------- | ------------------------------------------------------------ |
| `ANDROID_KEYSTORE_BASE64`   | the keystore as base64 (see below)                           |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password                                        |
| `ANDROID_KEY_ALIAS`         | `tide` (or the alias you chose)                              |
| `ANDROID_KEY_PASSWORD`      | the key password                                             |
| `SUPABASE_URL`              | same as in `product/.env` (optional: without it, demo mode)  |
| `SUPABASE_PUBLISHABLE_KEY`  | same as in `product/.env` (optional)                         |
| `GOOGLE_WEB_CLIENT_ID`      | same as in `product/.env` (optional)                         |

Base64 of the keystore:

```bash
# macOS / Linux
base64 -i tide-release.jks | tr -d '\n'
```

```powershell
# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("tide-release.jks")) | Set-Clipboard
```

### 3. Let the workflow push to `main`

**Settings → Actions → General → Workflow permissions → Read and write
permissions.** The release commits `public/version.json` back to `main`. If
`main` is branch-protected, allow GitHub Actions to bypass the rule, or the
last step fails (the GitHub Release is still created).

### 4. Where the app and the APK are fetched from (optional variables)

**Settings → Secrets and variables → Actions → Variables**

| Variable              | Default                                                               | Change it when                                   |
| --------------------- | --------------------------------------------------------------------- | ------------------------------------------------ |
| `UPDATE_MANIFEST_URL` | `https://raw.githubusercontent.com/<owner>/<repo>/main/public/version.json` | the website is live: use `https://<your-site>/version.json` |
| `APK_BASE_URL`        | the GitHub Release download URL                                       | you host APKs somewhere else                     |

Both defaults only work if the repository is **public**. For a private
repository, deploy the website and set `UPDATE_MANIFEST_URL` to its
`/version.json`, and host the APK somewhere public (`APK_BASE_URL`).

`UPDATE_MANIFEST_URL` is compiled into the app, so a change reaches people
from the next release onward.

## When something goes wrong

| Symptom | Fix |
| ------- | --- |
| Release says "vX.Y.Z is already released" | Expected on a normal push. Bump the version to release. |
| `CHANGELOG.md has no ## [X.Y.Z] section` | Add the dated section (or run `npm run release:patch`) and push again. |
| `still has the placeholder entry` | Replace `- Describe what changed.` with real notes. |
| `ANDROID_KEYSTORE_BASE64 is not set` | Do "One-time setup" above, then **Run workflow**. |
| Release created but `version.json` push failed | Fix the permission/branch protection, then run `node scripts/release.mjs manifest --url <apk url> --sha256 <sha from the release notes> --size <bytes>` locally and commit. |
| The app says the checksum did not match | The APK at the manifest URL is not the one released. Re-run the release or fix `version.json`. |
| Update installs fail with "App not installed" | The APK was signed with a different key than the installed app. Always use the one release key. |

## Files involved

| File | Role |
| ---- | ---- |
| `product/pubspec.yaml` | the version, the single source of truth |
| `CHANGELOG.md` | release notes: GitHub Release, website changelog, in-app update panel |
| `scripts/release.mjs` | bump, check, notes, manifest |
| `public/version.json` | the update manifest the app and the website read |
| `.github/workflows/ci.yml` | checks on every push and pull request |
| `.github/workflows/release.yml` | build, sign, publish |
| `product/lib/services/updates/` | the app's updater (pub_semver compare, download, sha256 check) |
| `product/android/app/src/main/kotlin/com/example/tide/UpdateInstaller.kt` | the install intent |
| `product/tool/site_screenshots_test.dart` | re-renders the website's app screenshots |
