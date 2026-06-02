"use client";

import { usePathname, useSearchParams } from "next/navigation";
import posthog from "posthog-js";
import { PostHogProvider as Provider } from "posthog-js/react";
import { Suspense, useEffect } from "react";

const key = process.env.NEXT_PUBLIC_POSTHOG_KEY;
const host = process.env.NEXT_PUBLIC_POSTHOG_HOST || "https://us.i.posthog.com";

if (typeof window !== "undefined" && key) {
  posthog.init(key, {
    api_host: host,
    capture_pageview: false,
    capture_pageleave: true,
    person_profiles: "identified_only",
  });
}

function PageviewCapture() {
  const pathname = usePathname();
  const searchParams = useSearchParams();

  useEffect(() => {
    if (!key || !pathname) return;
    const query = searchParams.toString();
    const url = query ? `${window.location.origin}${pathname}?${query}` : `${window.location.origin}${pathname}`;
    posthog.capture("$pageview", { $current_url: url });
  }, [pathname, searchParams]);

  return null;
}

export function PostHogProvider({ children }: { children: React.ReactNode }) {
  if (!key) return <>{children}</>;

  return (
    <Provider client={posthog}>
      <Suspense fallback={null}>
        <PageviewCapture />
      </Suspense>
      {children}
    </Provider>
  );
}
