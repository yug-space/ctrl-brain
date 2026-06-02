import type { Metadata } from "next";
import { PostHogProvider } from "./PostHogProvider";
import "./globals.css";

export const metadata: Metadata = {
  title: "Ctrl+Brain — your second brain, one keystroke away",
  description:
    "Press ⌃⇧2 anywhere. Ctrl+Brain captures the text, image, or screenshot in front of you, reads it on your Mac, and files it into one editable local second brain with optional Supermemory sync and MCP access.",
  metadataBase: new URL("https://ctrl-brain.vercel.app"),
  openGraph: {
    title: "Ctrl+Brain",
    description: "Your local second brain, one keystroke away.",
    type: "website",
  },
  icons: { icon: "/logo.svg" },
};

export const viewport = { themeColor: "#09090B", colorScheme: "dark" as const };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <PostHogProvider>{children}</PostHogProvider>
      </body>
    </html>
  );
}
