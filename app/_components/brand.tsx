import Image from "next/image";
import Link from "next/link";

/** The app icon and the name, as one link home. */
export function Brand() {
  return (
    <Link
      href="/"
      className="flex items-center gap-2.5 rounded-xl font-display text-lg font-medium tracking-tight focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-lantern"
    >
      <Image
        src="/tide-mark.png"
        alt=""
        width={32}
        height={32}
        className="size-8 rounded-[9px]"
      />
      <span translate="no">Tide</span>
    </Link>
  );
}
