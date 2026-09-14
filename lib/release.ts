import manifest from "@/public/version.json";

/**
 * The published release, as the release workflow last wrote it.
 *
 * The same file the app's updater fetches (public/version.json), so the site
 * and the app always agree on what the latest version is.
 */
export type Release = {
  version: string;
  build: number;
  releasedAt: string;
  minSupportedVersion: string;
  android: { url: string; sha256: string; size: number };
  notes: string[];
};

export const release: Release = manifest;

/** True once a real APK is published; false while the download is a stub. */
export const hasApk = release.android.url.startsWith("https://");

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
