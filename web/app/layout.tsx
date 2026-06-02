import type { Metadata } from "next";
import { Space_Grotesk, Instrument_Serif } from "next/font/google";
import "./globals.css";

const sans = Space_Grotesk({ subsets: ["latin"], variable: "--font-sans", display: "swap" });
const serif = Instrument_Serif({
  subsets: ["latin"],
  weight: "400",
  style: ["normal", "italic"],
  variable: "--font-serif",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Ctrl+Brain — your second brain, one keystroke away",
  description:
    "Press ⌃⇧2 anywhere. Ctrl+Brain captures the text, image, or screenshot in front of you, reads it on your Mac, and files it into one editable second brain — synced to Supermemory.",
  metadataBase: new URL("https://ctrl-brain.vercel.app"),
  openGraph: {
    title: "Ctrl+Brain",
    description: "Your second brain, one keystroke away.",
    type: "website",
  },
  icons: { icon: "/logo.svg" },
};

export const viewport = { themeColor: "#09090B", colorScheme: "dark" as const };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${sans.variable} ${serif.variable}`}>
      <body>{children}</body>
    </html>
  );
}
