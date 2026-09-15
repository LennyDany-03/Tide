import { DownloadSimple } from "@phosphor-icons/react/ssr";
import Link from "next/link";

type Props = {
  variant?: "primary" | "quiet";
  size?: "md" | "lg";
  className?: string;
};

const base =
  "group inline-flex items-center justify-center gap-2.5 whitespace-nowrap rounded-xl font-display font-medium transition-[transform,background-color,box-shadow,color] duration-300 ease-tide focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-lantern active:scale-[0.98]";

const variants = {
  primary:
    "bg-lantern text-on-lantern shadow-[0_10px_30px_-12px_var(--lantern)] hover:-translate-y-0.5 hover:shadow-[0_18px_40px_-14px_var(--lantern)]",
  quiet:
    "border border-hairline bg-shelf text-bone hover:-translate-y-0.5 hover:bg-shoal",
};

const sizes = {
  md: "h-10 px-4 text-sm",
  lg: "h-13 px-6 text-base",
};

/** Where every "Download Now" goes: the thank-you page, told to start the
 * APK download (app/thanks/start-download.tsx). */
export const DOWNLOAD_HREF = "/thanks?download";

/**
 * The one "Download Now" action, used everywhere on the site.
 *
 * It opens the thank-you page, which starts the download of the latest APK
 * from GitHub Releases and shows how to install it.
 */
export function DownloadButton({ variant = "primary", size = "lg", className = "" }: Props) {
  return (
    <Link
      href={DOWNLOAD_HREF}
      prefetch={false}
      className={`${base} ${variants[variant]} ${sizes[size]} ${className}`}
    >
      <DownloadSimple
        aria-hidden="true"
        weight="bold"
        className="size-[1.1em] transition-transform duration-300 ease-tide group-hover:translate-y-0.5"
      />
      Download Now
    </Link>
  );
}
