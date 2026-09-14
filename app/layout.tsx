import type { Metadata, Viewport } from "next";
import { Manrope, Space_Grotesk } from "next/font/google";
import "./globals.css";

// The app's own pairing (product/lib/theme/tide_typography.dart): Space
// Grotesk for display and figures, Manrope for everything at reading size.
const spaceGrotesk = Space_Grotesk({
  variable: "--font-space-grotesk",
  subsets: ["latin"],
  weight: ["500", "700"],
});

const manrope = Manrope({
  variable: "--font-manrope",
  subsets: ["latin"],
  weight: ["400", "500", "700"],
});

export const metadata: Metadata = {
  title: {
    default: "Tide: Habits That Move Like Water",
    template: "%s | Tide",
  },
  description:
    "A calm habit tracker for Android. Log a habit with one swipe, keep streaks through a missed day, and see your week at a glance.",
  applicationName: "Tide",
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f2f5f7" },
    { media: "(prefers-color-scheme: dark)", color: "#05080b" },
  ],
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      className={`${spaceGrotesk.variable} ${manrope.variable} antialiased`}
    >
      <body className="min-h-dvh font-sans">
        <a
          href="#main"
          className="sr-only rounded-xl bg-lantern px-4 py-2 font-medium text-on-lantern focus-visible:not-sr-only focus-visible:fixed focus-visible:top-3 focus-visible:left-3 focus-visible:z-50"
        >
          Skip to Content
        </a>
        {children}
      </body>
    </html>
  );
}
