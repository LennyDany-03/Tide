import {
  ArrowRight,
  Check,
  HandSwipeRight,
  ListChecks,
  Snowflake,
  SquaresFour,
} from "@phosphor-icons/react/ssr";
import Image from "next/image";
import Link from "next/link";
import { DownloadButton } from "./_components/download-button";
import { Phone } from "./_components/phone";
import { SiteFooter } from "./_components/site-footer";
import { SiteHeader } from "./_components/site-header";
import { formatDate, formatSize, release } from "@/lib/release";

/** The app's five palettes, from product/lib/theme/tide_palette.dart. */
const palettes = [
  { name: "Midnight", note: "Sky-blue light on near-black", ground: "#05080B", card: "#0C1217", ink: "#E8F1F6", accent: "#45D0FF", free: true },
  { name: "Deep water", note: "Warm lantern light over dark water", ground: "#071216", card: "#0E1D22", ink: "#EDE6DA", accent: "#E9B466" },
  { name: "Ink", note: "Black and white, nothing else", ground: "#0A0A0B", card: "#141415", ink: "#F2F1EE", accent: "#F2F1EE" },
  { name: "Blossom", note: "Pink paper with rose accents", ground: "#F9EEF1", card: "#FFF9FB", ink: "#3A1E28", accent: "#C93A6C" },
  { name: "Paper", note: "White paper, black ink", ground: "#F4F3EF", card: "#FFFFFF", ink: "#161616", accent: "#161616" },
];

/** From product/lib/config/plan_catalog.dart and pro_features.dart. */
const plans = {
  free: [
    "Up to 5 habits",
    "30 days of history",
    "2 streak freezes per habit",
    "Midnight palette",
    "To-do list with daily, weekly and monthly repeats",
    "Today's Habits widget",
  ],
  pro: [
    "Unlimited habits",
    "Full history and heatmaps",
    "Up to 7 streak freezes per habit",
    "All five palettes",
    "Tags, archive and several reminders for to-dos",
    "Dashboard, Heatmap and Weekly Recap widgets",
  ],
};

export default function Home() {
  const size = formatSize(release.android.size);

  return (
    <>
      <SiteHeader />
      <main id="main" className="overflow-x-clip">
        {/* Hero */}
        <section className="relative">
          <div
            aria-hidden="true"
            className="pointer-events-none absolute inset-x-0 top-0 h-[720px] bg-[radial-gradient(60%_60%_at_75%_30%,var(--glow),transparent_70%)]"
          />
          <div className="relative mx-auto grid max-w-7xl items-center gap-14 px-4 pt-12 pb-20 sm:px-6 md:pt-16 lg:grid-cols-12 lg:gap-8 lg:px-8 lg:pt-20 lg:pb-28">
            <div className="lg:col-span-6">
              <p className="rise text-sm font-medium text-lantern" style={{ "--i": 0 } as React.CSSProperties}>
                Free for Android
              </p>
              <h1
                className="rise mt-4 font-display text-5xl leading-[1.02] font-medium tracking-[-0.035em] sm:text-6xl lg:text-7xl"
                style={{ "--i": 1 } as React.CSSProperties}
              >
                Habits That Move Like Water.
              </h1>
              <p
                className="rise mt-6 max-w-[34rem] text-lg leading-relaxed text-silt"
                style={{ "--i": 2 } as React.CSSProperties}
              >
                Log a habit with one swipe, keep a streak through a missed day,
                and see your week at a glance.
              </p>
              <div
                className="rise mt-9 flex flex-wrap items-center gap-3"
                style={{ "--i": 3 } as React.CSSProperties}
              >
                <DownloadButton />
                <Link
                  href="/changelog"
                  className="group inline-flex h-13 items-center gap-2 rounded-xl px-4 font-display font-medium text-bone transition-colors hover:text-lantern focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-lantern"
                >
                  See What&rsquo;s New
                  <ArrowRight
                    aria-hidden="true"
                    weight="bold"
                    className="size-4 transition-transform duration-300 ease-tide group-hover:translate-x-1"
                  />
                </Link>
              </div>
            </div>

            <div className="relative mx-auto h-[540px] w-full max-w-[460px] sm:h-[620px] lg:col-span-6 lg:mr-0">
              <Phone
                screen="insights"
                alt="Tide's Insights screen: 75% of habits completed this week and an eight-week trend line."
                className="surface absolute top-10 left-3 w-[56%] opacity-90 lg:left-0 lg:w-[58%]"
                style={{ "--i": 0, "--tilt": "-6deg" } as React.CSSProperties}
                sizes="(min-width: 1024px) 270px, 58vw"
              />
              <Phone
                screen="today"
                alt="Tide's Today screen: 2 of 4 habits marked, a 23 day streak, and the habit list."
                priority
                className="surface absolute top-0 right-0 w-[62%]"
                style={{ "--i": 1, "--tilt": "3deg" } as React.CSSProperties}
                sizes="(min-width: 1024px) 290px, 62vw"
              />
            </div>
          </div>
        </section>

        {/* Features: an asymmetric bento, one cell per feature */}
        <section id="features" className="mx-auto max-w-7xl px-4 py-20 sm:px-6 lg:px-8 lg:py-28">
          <h2 className="reveal max-w-2xl font-display text-4xl leading-[1.08] font-medium tracking-[-0.03em] md:text-5xl">
            Logging Takes a Second. Keeping It Up Takes Less.
          </h2>

          <div className="mt-14 grid grid-cols-1 gap-4 md:grid-cols-12 md:gap-5">
            <article className="reveal relative flex min-h-[480px] flex-col overflow-hidden rounded-3xl border border-hairline bg-shelf md:col-span-7 md:row-span-2">
              <div className="p-8 md:p-10">
                <HandSwipeRight aria-hidden="true" className="size-7 text-lantern" />
                <h3 className="mt-5 font-display text-2xl font-medium tracking-tight">
                  Swipe to Keep the Day
                </h3>
                <p className="mt-3 max-w-md leading-relaxed text-silt">
                  A yes-or-no habit is one swipe. Counts step up with a hold,
                  and minutes turn on a dial.
                </p>
              </div>
              <div className="relative mt-auto h-[320px] overflow-hidden md:h-[380px]">
                {/* The same Today screen as the hero, framed on its habit
                    list rather than its header: the part this tile is about. */}
                <div className="absolute -top-[260px] left-1/2 w-[300px] -translate-x-1/2 md:-top-[290px] md:w-[340px]">
                  <Phone
                    screen="today"
                    alt="Four habit cards on Today, two already ticked."
                    sizes="340px"
                  />
                </div>
                <div
                  aria-hidden="true"
                  className="absolute inset-x-0 top-0 h-20 bg-linear-to-b from-shelf to-transparent"
                />
                <div
                  aria-hidden="true"
                  className="absolute inset-x-0 bottom-0 h-24 bg-linear-to-t from-shelf to-transparent"
                />
              </div>
            </article>

            <article className="reveal relative overflow-hidden rounded-3xl border border-hairline bg-[linear-gradient(135deg,color-mix(in_oklab,var(--lantern)_22%,var(--shelf)),var(--shelf)_70%)] p-8 md:col-span-5 md:p-10">
              <Snowflake aria-hidden="true" className="size-7 text-lantern" />
              <h3 className="mt-5 font-display text-2xl font-medium tracking-tight">
                A Missed Day Is Not a Lost Streak
              </h3>
              <p className="mt-3 leading-relaxed text-silt">
                Spend a streak freeze on a hard day, or pause a habit for a
                trip. The streak waits for you.
              </p>
            </article>

            <article className="reveal rounded-3xl border border-hairline bg-shelf p-8 md:col-span-5 md:p-10">
              <ListChecks aria-hidden="true" className="size-7 text-lantern" />
              <h3 className="mt-5 font-display text-2xl font-medium tracking-tight">
                To-dos Beside Your Habits
              </h3>
              <p className="mt-3 leading-relaxed text-silt">
                Due dates, repeats and reminders that still fire with no
                connection.
              </p>
            </article>

            <article className="reveal grid items-center gap-8 overflow-hidden rounded-3xl border border-hairline bg-shoal p-8 md:col-span-12 md:grid-cols-2 md:p-10">
              <div>
                <SquaresFour aria-hidden="true" className="size-7 text-lantern" />
                <h3 className="mt-5 font-display text-2xl font-medium tracking-tight">
                  Your Day on the Home Screen
                </h3>
                <p className="mt-3 max-w-md leading-relaxed text-silt">
                  Widgets for today&rsquo;s habits, your to-dos and your longest
                  streaks. Tap one to log without hunting for the app.
                </p>
              </div>
              <div className="flex items-center gap-4 md:justify-end">
                <Image
                  src="/tide-mark.png"
                  alt=""
                  width={96}
                  height={96}
                  className="size-20 rounded-[22px] shadow-[0_20px_40px_-20px_var(--shadow)] md:size-24"
                />
                <div>
                  <p className="font-display text-lg font-medium" translate="no">Tide</p>
                  <p className="text-sm text-silt">7 home screen widgets</p>
                </div>
              </div>
            </article>
          </div>
        </section>

        {/* History and insights: screens left, words right */}
        <section className="mx-auto grid max-w-7xl items-center gap-16 px-4 py-20 sm:px-6 lg:grid-cols-12 lg:gap-10 lg:px-8 lg:py-28">
          <div className="relative order-2 mx-auto grid w-full max-w-[520px] grid-cols-2 items-start gap-4 sm:gap-6 lg:order-1 lg:col-span-7">
            <Phone
              screen="history"
              alt="Tide's History screen: September as a calendar shaded by how much was logged each day."
              className="reveal"
              sizes="(min-width: 1024px) 250px, 45vw"
            />
            <Phone
              screen="insights"
              alt="Tide's Insights screen with the week's completion rate."
              className="reveal mt-16"
              sizes="(min-width: 1024px) 250px, 45vw"
            />
          </div>
          <div className="order-1 lg:order-2 lg:col-span-5">
            <h2 className="reveal font-display text-4xl leading-[1.08] font-medium tracking-[-0.03em] md:text-5xl">
              See the Shape of Your Month.
            </h2>
            <p className="reveal mt-6 max-w-md text-lg leading-relaxed text-silt">
              Every day you log fills a calendar, a year grid and an eight-week
              trend. Your strongest and quietest weekdays surface on their own.
            </p>
            <Link
              href="/changelog"
              className="reveal group mt-8 inline-flex items-center gap-2 rounded-xl font-display font-medium text-lantern focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-lantern"
            >
              Read the Changelog
              <ArrowRight
                aria-hidden="true"
                weight="bold"
                className="size-4 transition-transform duration-300 ease-tide group-hover:translate-x-1"
              />
            </Link>
          </div>
        </section>

        {/* Palettes: a full-width strip */}
        <section className="border-y border-hairline bg-shelf py-20 lg:py-28">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
            <h2 className="reveal max-w-xl font-display text-4xl leading-[1.08] font-medium tracking-[-0.03em] md:text-5xl">
              Five Palettes, One Calm App.
            </h2>
          </div>
          <ul className="mx-auto mt-12 flex max-w-7xl snap-x snap-mandatory scroll-px-4 gap-4 overflow-x-auto overscroll-x-contain px-4 pb-4 sm:scroll-px-6 sm:px-6 lg:grid lg:grid-cols-5 lg:overflow-visible lg:px-8">
            {palettes.map((palette) => (
              <li
                key={palette.name}
                className="reveal w-[220px] shrink-0 snap-start lg:w-auto"
              >
                <div
                  className="flex aspect-[3/4] flex-col justify-between rounded-3xl p-5 ring-1 ring-hairline"
                  style={{ background: palette.ground, color: palette.ink }}
                >
                  <div
                    className="rounded-2xl p-4"
                    style={{ background: palette.card }}
                  >
                    <div className="h-2 w-16 rounded-full" style={{ background: palette.accent }} />
                    <div className="mt-3 h-2 w-24 rounded-full opacity-30" style={{ background: palette.ink }} />
                    <div className="mt-2 h-2 w-12 rounded-full opacity-30" style={{ background: palette.ink }} />
                  </div>
                  <p className="font-display text-xl font-medium">{palette.name}</p>
                </div>
                <p className="mt-3 text-sm text-silt">
                  {palette.note}
                  {palette.free ? ". Free." : ". Pro."}
                </p>
              </li>
            ))}
          </ul>
        </section>

        {/* Pricing: two plans side by side */}
        <section id="pricing" className="mx-auto max-w-7xl px-4 py-20 sm:px-6 lg:px-8 lg:py-28">
          <h2 className="reveal max-w-2xl font-display text-4xl leading-[1.08] font-medium tracking-[-0.03em] md:text-5xl">
            Free to Start. Pro When You Want More.
          </h2>
          <div className="mt-14 grid gap-5 md:grid-cols-5">
            <div className="reveal rounded-3xl border border-hairline bg-shelf p-8 md:col-span-2 md:p-10">
              <h3 className="font-display text-2xl font-medium">Free</h3>
              <p className="mt-2 font-display text-4xl font-medium tabular-nums">₹0</p>
              <ul className="mt-8 space-y-3.5">
                {plans.free.map((item) => (
                  <li key={item} className="flex gap-3 text-silt">
                    <Check aria-hidden="true" weight="bold" className="mt-1 size-4 shrink-0 text-bone" />
                    {item}
                  </li>
                ))}
              </ul>
            </div>
            <div className="reveal relative overflow-hidden rounded-3xl border border-lantern/40 bg-shelf p-8 md:col-span-3 md:p-10">
              <div
                aria-hidden="true"
                className="pointer-events-none absolute -top-24 -right-24 size-72 rounded-full bg-[radial-gradient(closest-side,var(--glow),transparent)]"
              />
              <h3 className="relative font-display text-2xl font-medium">
                <span translate="no">Tide</span> Pro
              </h3>
              <p className="relative mt-2 font-display text-4xl font-medium tabular-nums">
                ₹499<span className="text-lg text-silt"> / year</span>
              </p>
              <p className="relative mt-1 text-sm text-silt tabular-nums">or ₹100 / month, cancel any time</p>
              <ul className="relative mt-8 grid gap-3.5 sm:grid-cols-2">
                {plans.pro.map((item) => (
                  <li key={item} className="flex gap-3">
                    <Check aria-hidden="true" weight="bold" className="mt-1 size-4 shrink-0 text-lantern" />
                    {item}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </section>

        {/* Download */}
        <section className="px-4 pb-24 sm:px-6 lg:px-8 lg:pb-32">
          <div className="reveal relative mx-auto max-w-7xl overflow-hidden rounded-3xl border border-hairline bg-shelf px-6 py-16 sm:px-12 lg:py-20">
            <div
              aria-hidden="true"
              className="pointer-events-none absolute inset-0 bg-[radial-gradient(50%_80%_at_85%_100%,var(--glow),transparent_70%)]"
            />
            <div className="relative grid items-end gap-10 lg:grid-cols-12">
              <div className="lg:col-span-8">
                <h2 className="font-display text-4xl leading-[1.05] font-medium tracking-[-0.03em] md:text-6xl">
                  Start Your First Habit Tonight.
                </h2>
                <p className="mt-5 max-w-lg text-lg leading-relaxed text-silt">
                  <span translate="no">Tide</span>{" "}
                  <span className="tabular-nums">{release.version}</span> for Android,
                  released {formatDate(release.releasedAt)}
                  {size ? <>, <span className="tabular-nums">{size}</span></> : null}.
                  New versions install from inside the app.
                </p>
              </div>
              <div className="lg:col-span-4 lg:justify-self-end">
                <DownloadButton />
              </div>
            </div>
          </div>
        </section>
      </main>
      <SiteFooter />
    </>
  );
}
