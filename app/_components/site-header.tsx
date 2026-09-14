import Link from "next/link";
import { Brand } from "./brand";
import { DownloadButton } from "./download-button";

const links = [
  { href: "/#features", label: "Features" },
  { href: "/#pricing", label: "Pricing" },
  { href: "/changelog", label: "Changelog" },
];

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-40 border-b border-hairline bg-ground/80 backdrop-blur-md">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between gap-6 px-4 sm:px-6 lg:px-8">
        <Brand />
        <nav aria-label="Main" className="flex items-center gap-1 sm:gap-2">
          <ul className="hidden items-center gap-1 md:flex">
            {links.map((link) => (
              <li key={link.href}>
                <Link
                  href={link.href}
                  className="rounded-xl px-3 py-2 text-sm text-silt transition-colors duration-200 hover:text-bone focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-lantern"
                >
                  {link.label}
                </Link>
              </li>
            ))}
          </ul>
          <DownloadButton size="md" />
        </nav>
      </div>
    </header>
  );
}
