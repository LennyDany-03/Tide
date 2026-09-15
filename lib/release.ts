import fallback from "./release-fallback.json";

/**
 * The published release, as described by the update manifest.
 *
 * The release workflow attaches version.json to every GitHub Release, and
 * GitHub's /releases/latest/download/ path always points at the newest one.
 * The app's updater reads the same URL, so the site and the app agree on
 * what the latest version is without anything being committed to main.
 */
export type Release = {
  version: string;
  build: number;
  releasedAt: string;
  minSupportedVersion: string;
  android: { url: string; sha256: string; size: number };
  notes: string[];
};

export const MANIFEST_URL =
  process.env.TIDE_MANIFEST_URL ??
  "https://github.com/LennyDany-03/Tide/releases/latest/download/version.json";

/**
 * How often, in seconds, the site looks for a newer release on its own. A
 * release normally refreshes the site at once through /api/revalidate; this
 * is the backstop for when that call is not configured or fails.
 */
export const RELEASE_REVALIDATE = 300;

/** Cache tag on the manifest fetch, cleared by /api/revalidate. */
export const RELEASE_TAG = "release";

function isRelease(value: unknown): value is Release {
  const v = value as Release;
  return (
    typeof v?.version === "string" &&
    typeof v.releasedAt === "string" &&
    typeof v.android?.url === "string" &&
    Array.isArray(v.notes)
  );
}

/**
 * The latest release, re-fetched at most every RELEASE_REVALIDATE seconds.
 * Falls back to the copy bundled at build time (lib/release-fallback.json)
 * when GitHub cannot be reached or there is no release with a manifest yet.
 */
export async function getRelease(): Promise<Release> {
  try {
    const response = await fetch(MANIFEST_URL, {
      next: { revalidate: RELEASE_REVALIDATE, tags: [RELEASE_TAG] },
    });
    if (response.ok) {
      const data: unknown = await response.json();
      if (isRelease(data)) return data;
    }
  } catch {
    // Offline build or GitHub unavailable: the bundled copy is still true.
  }
  return fallback;
}

/** True once a real APK is published. */
export function hasApk(release: Release) {
  return release.android.url.startsWith("https://");
}

export function formatDate(iso: string) {
  const date = new Date(`${iso}T00:00:00Z`);
  if (Number.isNaN(date.getTime())) return iso;
  return new Intl.DateTimeFormat("en", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(date);
}

export function formatSize(bytes: number) {
  if (!bytes) return null;
  return new Intl.NumberFormat("en", {
    style: "unit",
    unit: "megabyte",
    maximumFractionDigits: 1,
  }).format(bytes / 1_000_000);
}
