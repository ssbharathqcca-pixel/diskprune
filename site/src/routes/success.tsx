import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { Button } from "@/components/ui/button";
import { PRODUCT } from "@/lib/product";
import { getStoredLicense, issueLicense, saveLicense, verifyLicense } from "@/lib/license";
import { usePruneStore } from "@/lib/prune-store";

export const Route = createFileRoute("/success")({
  component: SuccessPage,
  validateSearch: (search: Record<string, unknown>) => ({
    session_id: typeof search.session_id === "string" ? search.session_id : undefined,
  }),
  head: () => ({
    meta: [{ title: "Thank you — DiskPrune" }],
  }),
});

function SuccessPage() {
  const { session_id: sessionId } = Route.useSearch();
  const [key, setKey] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const activate = usePruneStore((s) => s.activate);

  useEffect(() => {
    const existing = getStoredLicense();
    if (existing && verifyLicense(existing)) {
      setKey(existing);
      activate(existing);
      return;
    }
    const issued = issueLicense();
    saveLicense(issued);
    activate(issued);
    setKey(issued);
  }, [activate]);

  return (
    <div className="min-h-dvh">
      <SiteHeader />
      <main className="mx-auto max-w-lg px-4 py-20 text-center sm:px-6">
        <div className="rounded-2xl bg-card px-6 py-10 shadow-[var(--shadow-border)]">
          <p className="text-xs font-medium uppercase tracking-widest text-ok">
            {sessionId ? "Payment received" : "License issued"}
          </p>
          <h1 className="mt-3 text-3xl font-semibold tracking-tight">You are licensed.</h1>
          <p className="mt-3 text-sm leading-relaxed text-muted-foreground">
            Paste this key when DiskPrune asks. On a real purchase the worker at
            api.diskprune.com maps the Stripe session to the same PRUNE-XXXX format.
          </p>
          {key ? (
            <div className="mt-8">
              <p className="text-xs uppercase tracking-widest text-faint">Your license key</p>
              <code className="mt-2 block select-all font-mono text-lg tracking-wide text-accent">
                {key}
              </code>
              <Button
                className="mt-4"
                variant="secondary"
                onClick={() => {
                  void navigator.clipboard.writeText(key);
                  setCopied(true);
                  setTimeout(() => setCopied(false), 1600);
                }}
              >
                {copied ? "Copied" : "Copy"}
              </Button>
            </div>
          ) : (
            <p className="mt-8 animate-pulse text-sm text-muted-foreground">
              Generating your license key…
            </p>
          )}
          <div className="mt-8 flex flex-col gap-3">
            <Button asChild>
              <a href={PRODUCT.dmgUrl}>Download DiskPrune</a>
            </Button>
            <Button asChild variant="ghost">
              <a href="/app">Open the app demo</a>
            </Button>
          </div>
        </div>
      </main>
      <SiteFooter />
    </div>
  );
}
