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
               └─ GitHub Release vX.Y.Z  + tide-X.Y.Z.apk  + version.json
                        │
                        │  github.com/<owner>/<repo>/releases/latest/download/version.json
                        │  always points at the newest release, so:
                        ├─► website shows the new version within 15 minutes
                        └─► installed apps see the update and install it
```

Nothing is ever committed back to `main`, so `main` can require pull requests.

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

- **Releases** on GitHub has `vX.Y.Z` with `tide-X.Y.Z.apk`, its SHA-256 and
  `version.json` (the update manifest).
- The website re-reads that manifest every 15 minutes, with no redeploy
  needed: it shows the new version, and the thank-you page links to the
  real APK. The changelog page updates when the merge to `main` redeploys
  the site.
- Installed apps find the update on their next launch (or when reopened
  after 6 hours), show "Tide X.Y.Z is ready" once, and keep it under
  **Settings → App updates** after that.

## Releasing by hand

**Actions → Release → Run workflow** runs the same pipeline on the current
`main` without waiting for CI. It still skips a version that is already
tagged, so it is safe to press twice. If a release exists but is missing its
`version.json`, pressing it attaches the manifest without rebuilding.

## Starting a release over

To throw away a release (for example a bad build nobody has installed):

1. **Releases** → open `vX.Y.Z` → **Delete** (trash icon).
2. **Tags** (from the Releases page) → open `vX.Y.Z` → **⋯** → **Delete tag**.
   Deleting the release alone leaves the tag, and a tag counts as released.
3. **Actions → Release → Run workflow**.

Once people have installed a version, do not delete it: bump to the next
patch instead.

## Forcing everyone to update

**Settings → Secrets and variables → Actions → Variables → New variable**:
`MIN_SUPPORTED_VERSION` = for example `1.1.0`. It is written into the
manifest of the next release, and installs older than that see an update
panel they cannot dismiss.

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

### 3. Let the workflow create releases

**Settings → Actions → General → Workflow permissions → Read and write
permissions.** This lets it create tags and releases. It does not need to
push to `main`, so a "changes must be made through a pull request" rule on
`main` is fine.

### 4. Optional variables

**Settings → Secrets and variables → Actions → Variables**

| Variable                | Default                                                          | Change it when                                   |
| ----------------------- | ---------------------------------------------------------------- | ------------------------------------------------ |
| `UPDATE_MANIFEST_URL`   | `https://github.com/<owner>/<repo>/releases/latest/download/version.json` | you want the app to read `https://<your-site>/version.json` instead |
| `APK_BASE_URL`          | the GitHub Release download URL                                  | you host APKs somewhere else                     |
| `MIN_SUPPORTED_VERSION` | `1.0.0`                                                          | you want to force older installs to update       |

The defaults only work while the repository is **public**: GitHub Release
downloads of a private repository need a login, which the app does not have.

`UPDATE_MANIFEST_URL` is compiled into the app, so a change reaches people
from the next release onward.

## When something goes wrong

| Symptom | Fix |
| ------- | --- |
| Release says "vX.Y.Z is already released" | Expected on a normal push. Bump the version to release. |
| `CHANGELOG.md has no ## [X.Y.Z] section` | Add the dated section (or run `npm run release:patch`) and push again. |
| `still has the placeholder entry` | Replace `- Describe what changed.` with real notes. |
| `ANDROID_KEYSTORE_BASE64 is not set` | Do "One-time setup" above, then **Run workflow**. |
| Release exists but has no `version.json` | **Actions → Release → Run workflow**. It attaches the manifest without rebuilding. |
| `Tag vX.Y.Z exists but has no GitHub Release` | Delete the tag (see "Starting a release over") or bump the version. |
| The app says the checksum did not match | The APK in the release is not the one the manifest describes. Start the release over. |
| Update installs fail with "App not installed" | The APK was signed with a different key than the installed app. Always use the one release key. |

## Files involved

| File | Role |
| ---- | ---- |
| `product/pubspec.yaml` | the version, the single source of truth |
| `CHANGELOG.md` | release notes: GitHub Release, website changelog, in-app update panel |
| `scripts/release.mjs` | bump, check, notes, manifest |
| `version.json` (a GitHub Release asset) | the update manifest the app and the website read |
| `lib/release-fallback.json` | the website's offline copy of the manifest |
| `app/version.json/route.ts` | the manifest mirrored at `https://<your-site>/version.json` |
| `.github/workflows/ci.yml` | checks on every push and pull request |
| `.github/workflows/release.yml` | build, sign, publish |
| `product/lib/services/updates/` | the app's updater (pub_semver compare, download, sha256 check) |
| `product/android/app/src/main/kotlin/com/example/tide/UpdateInstaller.kt` | the install intent |
| `product/tool/site_screenshots_test.dart` | re-renders the website's app screenshots |
