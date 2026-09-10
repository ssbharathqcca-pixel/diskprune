import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { Button } from "@/components/ui/button";
import { PRODUCT } from "@/lib/product";
import {
  copyFor,
  interpretResponse,
  parseSessionId,
  POLL_LIMIT,
  POLL_MS,
  shouldPoll,
  statusUrl,
  type CheckoutView,
} from "@/lib/checkout-status";

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
  const [heading, setHeading] = useState("Checking your payment");
  const [body, setBody] = useState("Checking payment status…");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const valid = parseSessionId(sessionId ? `session_id=${sessionId}` : "");
    let cancelled = false;

    const apply = (view: CheckoutView) => {
      if (cancelled) return;
      const copy = copyFor(view);
      setHeading(copy.heading);
      setBody(copy.body);
      setLoading(false);
    };

    if (!valid) {
      apply({ payment_state: "unknown", delivery_state: "unknown", email_masked: null });
      return;
    }

    const load = async () => {
      let view: CheckoutView = { payment_state: "unknown", delivery_state: "unknown", email_masked: null };
      let polls = 0;
      while (true) {
        try {
          const res = await fetch(statusUrl(valid), {
            method: "GET",
            headers: { Accept: "application/json" },
            credentials: "omit",
          });
          const payload = (await res.json()) as Record<string, unknown>;
          view = interpretResponse(res.status, payload);
        } catch {
          view = { payment_state: "unknown", delivery_state: "unknown", email_masked: null };
        }
        if (!shouldPoll(view) || polls >= POLL_LIMIT) break;
        polls += 1;
        await new Promise((r) => setTimeout(r, POLL_MS));
      }
      if (shouldPoll(view)) view = { ...view, pollExhausted: true };
      apply(view);
    };

    void load();
    return () => {
      cancelled = true;
    };
  }, [sessionId]);

  return (
    <div className="min-h-dvh">
      <SiteHeader />
      <main className="mx-auto max-w-lg px-4 py-20 text-center sm:px-6">
        <div className="rounded-2xl bg-card px-6 py-10 shadow-[var(--shadow-border)]">
          <h1 className="text-3xl font-semibold tracking-tight">{heading}</h1>
          {loading ? (
            <p className="mt-8 animate-pulse text-sm text-muted-foreground">{body}</p>
          ) : (
            <p className="mt-3 text-sm leading-relaxed text-muted-foreground">{body}</p>
          )}
          <p className="mt-6 text-xs text-faint">
            DiskPrune never shows a license key on this page. If payment is confirmed, the key is in
            your email. Paste it in DiskPrune → Settings → Licence.
          </p>
          <div className="mt-8 flex flex-col gap-3">
            <Button asChild>
              <a href={PRODUCT.dmgUrl}>Download DiskPrune</a>
            </Button>
          </div>
        </div>
      </main>
      <SiteFooter />
    </div>
  );
}
