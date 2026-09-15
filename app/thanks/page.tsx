import {
  ArrowLeft,
  ArrowUpRight,
  FileArrowDown,
  GearSix,
  ShieldCheck,
} from "@phosphor-icons/react/ssr";
import type { Metadata } from "next";
import Link from "next/link";
import { Phone } from "../_components/phone";
import { SiteFooter } from "../_components/site-footer";
import { SiteHeader } from "../_components/site-header";
import { formatDate, formatSize, getRelease, hasApk } from "@/lib/release";

// Picks up a new GitHub Release without a redeploy (see lib/release.ts).
export const revalidate = 900;

export const metadata: Metadata = {
  title: "Thanks for Downloading",
  description: "Install Tide on your Android phone in three short steps.",
  // A page reached by pressing a button, not a page to be found by search.
  robots: { index: false },
};

const steps = [
  {
    icon: FileArrowDown,
    title: "Open the APK",
    body: "When the download finishes, tap it in your notifications or your Downloads folder.",
  },
  {
    icon: GearSix,
    title: "Allow the Install",
    body: "Android asks once whether your browser may install apps. Allow it, then go back.",
  },
  {
    icon: ShieldCheck,
    title: "Open Tide",
    body: "Tap Install, then Open. Future updates arrive inside the app, so this is the only time.",
  },
];

export default async function ThanksPage() {
  const release = await getRelease();
  const size = formatSize(release.android.size);

  return (
    <>
      <SiteHeader />
      <main id="main" className="relative overflow-x-clip">
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-x-0 top-0 h-[640px] bg-[radial-gradient(55%_60%_at_20%_20%,var(--glow),transparent_70%)]"
        />
        <div className="relative mx-auto grid max-w-7xl items-center gap-16 px-4 pt-12 pb-24 sm:px-6 md:pt-16 lg:grid-cols-12 lg:gap-10 lg:px-8 lg:pt-20 lg:pb-32">
          <div className="lg:col-span-7">
            <h1
              className="rise font-display text-5xl leading-[1.02] font-medium tracking-[-0.035em] sm:text-6xl"
              style={{ "--i": 0 } as React.CSSProperties}
            >
              Thanks for Downloading <span translate="no">Tide</span>.
            </h1>
            <p
              className="rise mt-6 max-w-xl text-lg leading-relaxed text-silt"
              style={{ "--i": 1 } as React.CSSProperties}
            >
              <span translate="no">Tide</span>{" "}
              <span className="tabular-nums">{release.version}</span> for Android
              {size ? <> (<span className="tabular-nums">{size}</span>)</> : null},
              released {formatDate(release.releasedAt)}. Three steps and your
              first habit is one swipe away.
            </p>

            {hasApk(release) ? (
              <p
                className="rise mt-4 text-sm text-silt"
                style={{ "--i": 2 } as React.CSSProperties}
              >
                Download didn&rsquo;t start?{" "}
                <a
                  href={release.android.url}
                  className="inline-flex items-center gap-1 font-medium text-lantern underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-lantern"
                >
                  Download the APK Directly
                  <ArrowUpRight aria-hidden="true" weight="bold" className="size-3.5" />
                </a>
              </p>
            ) : null}

            <ol className="mt-12 grid gap-4 sm:grid-cols-3 lg:max-w-2xl">
              {steps.map((step, i) => (
                <li
                  key={step.title}
                  className="rise rounded-3xl border border-hairline bg-shelf p-6"
                  style={{ "--i": i + 3 } as React.CSSProperties}
                >
                  <step.icon aria-hidden="true" className="size-6 text-lantern" />
                  <h2 className="mt-4 font-display text-lg font-medium">{step.title}</h2>
                  <p className="mt-2 text-sm leading-relaxed text-silt">{step.body}</p>
                </li>
              ))}
            </ol>

            <div
              className="rise mt-10 flex flex-wrap items-center gap-x-6 gap-y-3"
              style={{ "--i": 6 } as React.CSSProperties}
            >
              <Link
                href="/"
                className="group inline-flex h-12 items-center gap-2 rounded-xl border border-hairline bg-shelf px-5 font-display font-medium transition-[transform,background-color] duration-300 ease-tide hover:-translate-y-0.5 hover:bg-shoal focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-lantern active:scale-[0.98]"
              >
                <ArrowLeft
                  aria-hidden="true"
                  weight="bold"
                  className="size-4 transition-transform duration-300 ease-tide group-hover:-translate-x-1"
                />
                Back to Home
              </Link>
              <Link
                href="/changelog"
                className="rounded-xl font-display font-medium text-lantern underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-lantern"
              >
                See What&rsquo;s New
              </Link>
            </div>
          </div>

          <div className="relative mx-auto w-full max-w-[300px] lg:col-span-5 lg:max-w-[320px]">
            <Phone
              screen="today"
              alt="Tide's Today screen, the first thing you see after signing in."
              priority
              className="surface"
              style={{ "--i": 0, "--tilt": "4deg" } as React.CSSProperties}
              sizes="(min-width: 1024px) 320px, 300px"
            />
          </div>
        </div>
      </main>
      <SiteFooter />
    </>
  );
}
