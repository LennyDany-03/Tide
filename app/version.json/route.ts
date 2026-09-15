import { getRelease, RELEASE_REVALIDATE } from "@/lib/release";

// The update manifest on the site's own domain, mirrored from the latest
// GitHub Release. Useful as UPDATE_MANIFEST_URL once the site is live.
export const dynamic = "force-static";
export const revalidate = 900;

export async function GET() {
  const release = await getRelease();
  return Response.json(release, {
    headers: {
      "Cache-Control": `public, max-age=60, s-maxage=${RELEASE_REVALIDATE}`,
    },
  });
}
