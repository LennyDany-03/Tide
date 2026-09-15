import { createHash, timingSafeEqual } from "node:crypto";
import { revalidatePath, revalidateTag } from "next/cache";
import { MANIFEST_URL, RELEASE_TAG } from "@/lib/release";

/**
 * Called by the release workflow once a GitHub Release is up, so the site
 * shows the new version straight away instead of on its next scheduled
 * refresh (RELEASE_REVALIDATE).
 *
 *   POST /api/revalidate
 *   Authorization: Bearer <REVALIDATE_SECRET>
 *   { "version": "1.0.2" }
 *
 * GitHub's latest/download link can lag a new release by a minute or so. If
 * the cache were cleared during that minute, the next visit would store the
 * old manifest again for the whole revalidate window. So the manifest is read
 * fresh here first, and while it does not name `version` yet this answers 409
 * and clears nothing; the workflow waits and tries again.
 */
export async function POST(request: Request) {
  const secret = process.env.REVALIDATE_SECRET;
  if (!secret) {
    return Response.json({ error: "REVALIDATE_SECRET is not set on the site." }, { status: 503 });
  }
  const given = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!sameSecret(given, secret)) {
    return Response.json({ error: "Unauthorized." }, { status: 401 });
  }

  const body: unknown = await request.json().catch(() => null);
  const expected = (body as { version?: unknown } | null)?.version;

  let published: string | null = null;
  try {
    const response = await fetch(MANIFEST_URL, { cache: "no-store" });
    if (response.ok) {
      const manifest = (await response.json()) as { version?: unknown };
      if (typeof manifest.version === "string") published = manifest.version;
    }
  } catch {
    // Reported below as "not published yet".
  }

  if (typeof expected === "string" && published !== expected) {
    return Response.json({ revalidated: false, expected, published }, { status: 409 });
  }

  revalidateTag(RELEASE_TAG, { expire: 0 });
  revalidatePath("/", "layout");
  return Response.json({ revalidated: true, published });
}

/** Compares digests, so neither the secret's length nor its prefix leaks. */
function sameSecret(given: string, secret: string) {
  const digest = (value: string) => createHash("sha256").update(value).digest();
  return timingSafeEqual(digest(given), digest(secret));
}
