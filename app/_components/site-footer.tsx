import Link from "next/link";
import { release } from "@/lib/release";
import { Brand } from "./brand";

export function SiteFooter() {
  return (
    <footer className="border-t border-hairline">
      <div className="mx-auto flex max-w-7xl flex-col gap-8 px-4 py-12 sm:px-6 md:flex-row md:items-center md:justify-between lg:px-8">
        <div className="flex flex-col gap-3">
          <Brand />
          <p className="max-w-xs text-sm text-silt">
            Habits that move like water. Small, daily, repeating.
          </p>
        </div>
        <nav aria-label="Footer">
          <ul className="flex flex-wrap gap-x-6 gap-y-3 text-sm">
            <li>
              <Link href="/#features" className="text-silt transition-colors hover:text-bone">
                Features
              </Link>
            </li>
            <li>
              <Link href="/#pricing" className="text-silt transition-colors hover:text-bone">
                Pricing
              </Link>
            </li>
            <li>
              <Link href="/changelog" className="text-silt transition-colors hover:text-bone">
                Changelog
              </Link>
            </li>
            <li>
              <Link href="/thanks" className="text-silt transition-colors hover:text-bone">
                Download Now
              </Link>
            </li>
          </ul>
        </nav>
        <p className="text-sm text-silt">
          <span translate="no">Tide</span>{" "}
          <span className="tabular-nums">{release.version}</span> for Android
          <br />© {new Date(`${release.releasedAt}T00:00:00Z`).getUTCFullYear()} Tide
        </p>
      </div>
    </footer>
  );
}
