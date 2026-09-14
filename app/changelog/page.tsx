import type { Metadata } from "next";
import { DownloadButton } from "../_components/download-button";
import { SiteFooter } from "../_components/site-footer";
import { SiteHeader } from "../_components/site-header";
import { parseInline, readChangelog, type InlinePart } from "@/lib/changelog";
import { formatDate, release } from "@/lib/release";

export const metadata: Metadata = {
  title: "Changelog",
  description: "Every release of Tide for Android, newest first.",
};

function Inline({ parts }: { parts: InlinePart[] }) {
  return parts.map((part, i) => {
    switch (part.kind) {
      case "code":
        return (
          <code key={i} className="rounded-md bg-shoal px-1.5 py-0.5 text-[0.9em]">
            {part.value}
          </code>
        );
      case "strong":
        return (
          <strong key={i} className="font-semibold text-bone">
            {part.value}
          </strong>
        );
      case "link":
        return (
          <a
            key={i}
            href={part.href}
            className="text-lantern underline-offset-4 hover:underline"
          >
            {part.value}
          </a>
        );
      default:
        return <span key={i}>{part.value}</span>;
    }
  });
}

export default function ChangelogPage() {
  const entries = readChangelog();

  return (
    <>
      <SiteHeader />
      <main id="main" className="mx-auto max-w-7xl px-4 pt-12 pb-24 sm:px-6 md:pt-16 lg:px-8 lg:pt-20 lg:pb-32">
        <div className="grid gap-8 border-b border-hairline pb-12 md:grid-cols-12 md:items-end">
          <div className="md:col-span-8">
            <h1
              className="rise font-display text-5xl leading-[1.02] font-medium tracking-[-0.035em] sm:text-6xl"
              style={{ "--i": 0 } as React.CSSProperties}
            >
              Changelog
            </h1>
            <p
              className="rise mt-5 max-w-lg text-lg leading-relaxed text-silt"
              style={{ "--i": 1 } as React.CSSProperties}
            >
              Every release of <span translate="no">Tide</span> for Android. The
              latest is <span className="tabular-nums text-bone">{release.version}</span>.
            </p>
          </div>
          <div
            className="rise md:col-span-4 md:justify-self-end"
            style={{ "--i": 2 } as React.CSSProperties}
          >
            <DownloadButton />
          </div>
        </div>

        {entries.length === 0 ? (
          <p className="py-16 text-silt">
            No releases yet. The first one will be listed here.
          </p>
        ) : (
          <ol className="divide-y divide-hairline">
            {entries.map((entry) => (
              <li
                key={entry.version}
                id={`v${entry.version}`}
                className="reveal grid gap-6 py-12 md:grid-cols-12 md:gap-10"
              >
                <div className="md:col-span-4">
                  <div className="md:sticky md:top-24">
                    <h2 className="font-display text-3xl font-medium tracking-tight tabular-nums">
                      {entry.version}
                    </h2>
                    {entry.date ? (
                      <p className="mt-2 text-sm text-silt">
                        <time dateTime={entry.date}>{formatDate(entry.date)}</time>
                      </p>
                    ) : null}
                  </div>
                </div>
                <div className="space-y-8 md:col-span-8">
                  {entry.groups
                    .filter((group) => group.items.length > 0)
                    .map((group) => (
                      <section key={group.title}>
                        <h3 className="font-display text-sm font-medium text-lantern">
                          {group.title}
                        </h3>
                        <ul className="mt-4 space-y-3">
                          {group.items.map((item) => (
                            <li
                              key={item}
                              className="relative pl-5 leading-relaxed break-words text-silt before:absolute before:top-[0.7em] before:left-0 before:h-px before:w-2.5 before:bg-silt/60"
                            >
                              <Inline parts={parseInline(item)} />
                            </li>
                          ))}
                        </ul>
                      </section>
                    ))}
                </div>
              </li>
            ))}
          </ol>
        )}
      </main>
      <SiteFooter />
    </>
  );
}
