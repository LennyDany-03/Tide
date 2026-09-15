"use client";

import { ArrowUpRight, DownloadSimple } from "@phosphor-icons/react";
import { useEffect, useState } from "react";

type Props = {
  url: string;
  size: string | null;
};

/** Query flag the "Download Now" buttons add. See DownloadButton. */
export const DOWNLOAD_PARAM = "download";

/**
 * Starts the APK download when the page was reached from a "Download Now"
 * button, and offers the link otherwise.
 *
 * The flag is removed from the address before the download starts, so a
 * refresh, a back button or a shared link never downloads the file again.
 * GitHub serves the APK as an attachment, so navigating to it downloads the
 * file and leaves this page where it is.
 */
export function StartDownload({ url, size }: Props) {
  const [started, setStarted] = useState(false);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (!params.has(DOWNLOAD_PARAM)) return;

    params.delete(DOWNLOAD_PARAM);
    const query = params.toString();
    window.history.replaceState(
      window.history.state,
      "",
      `${window.location.pathname}${query ? `?${query}` : ""}${window.location.hash}`,
    );

    // A beat after the page appears, so the thank-you reads first and the
    // browser's download prompt does not land on a blank screen.
    const timer = window.setTimeout(() => {
      window.location.assign(url);
      setStarted(true);
    }, 600);
    return () => window.clearTimeout(timer);
  }, [url]);

  return (
    <div aria-live="polite" className="mt-8">
      {started ? (
        <p className="text-silt">
          <span className="font-medium text-bone">Your download has started.</span>{" "}
          Didn&rsquo;t start?{" "}
          <a
            href={url}
            className="inline-flex items-center gap-1 font-medium text-lantern underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-lantern"
          >
            Download the APK Directly
            <ArrowUpRight aria-hidden="true" weight="bold" className="size-3.5" />
          </a>
        </p>
      ) : (
        <a
          href={url}
          className="group inline-flex h-13 items-center gap-2.5 rounded-xl bg-lantern px-6 font-display font-medium whitespace-nowrap text-on-lantern shadow-[0_10px_30px_-12px_var(--lantern)] transition-[transform,box-shadow] duration-300 ease-tide hover:-translate-y-0.5 hover:shadow-[0_18px_40px_-14px_var(--lantern)] focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-lantern active:scale-[0.98]"
        >
          <DownloadSimple
            aria-hidden="true"
            weight="bold"
            className="size-[1.1em] transition-transform duration-300 ease-tide group-hover:translate-y-0.5"
          />
          Download the APK
          {size ? <span className="font-sans text-sm opacity-75 tabular-nums">{size}</span> : null}
        </a>
      )}
    </div>
  );
}
