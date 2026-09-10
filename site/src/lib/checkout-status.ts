const API_ORIGIN = "https://api.diskprune.com";
export const SUPPORT_EMAIL = "support@diskprune.com";
export const POLL_LIMIT = 3;
export const POLL_MS = 2000;
const SESSION_RE = /^cs_[A-Za-z0-9_]{6,250}$/;

export type CheckoutView = {
  payment_state: string;
  delivery_state: string;
  email_masked: string | null;
  pollExhausted?: boolean;
};

export function parseSessionId(search: string | undefined): string | null {
  const raw = String(search || "");
  const value = new URLSearchParams(raw.startsWith("?") ? raw.slice(1) : raw).get("session_id");
  if (!value || !SESSION_RE.test(value)) return null;
  return value;
}

export function statusUrl(sessionId: string): string {
  return `${API_ORIGIN}/v1/checkout/${encodeURIComponent(sessionId)}/status`;
}

export function shouldPoll(view: CheckoutView): boolean {
  return view.payment_state === "paid" && view.delivery_state === "pending" && !view.pollExhausted;
}

export function copyFor(view: CheckoutView): { kind: string; heading: string; body: string; confirmed: boolean } {
  const email = view.email_masked;
  if (view.payment_state === "paid" && view.delivery_state === "sent") {
    const dest = email ? ` — we sent it to ${email}` : "";
    return {
      kind: "paid-sent",
      heading: "Payment confirmed",
      body: `Payment confirmed. Your license key is in your email${dest}.`,
      confirmed: true,
    };
  }
  if (view.payment_state === "paid" && view.delivery_state === "pending") {
    const support = view.pollExhausted
      ? ` If it doesn't arrive, email ${SUPPORT_EMAIL} and we'll sort it out.`
      : "";
    return {
      kind: "paid-pending",
      heading: "Payment confirmed",
      body: `Payment confirmed. Your key is being generated — check your email in a minute.${support}`,
      confirmed: true,
    };
  }
  if (view.payment_state === "paid") {
    return {
      kind: "paid-email-failed",
      heading: "Payment confirmed",
      body: `Payment confirmed. We couldn't send the license email. Email ${SUPPORT_EMAIL} and we'll sort it out.`,
      confirmed: true,
    };
  }
  if (view.payment_state === "unpaid") {
    return {
      kind: "unpaid",
      heading: "Payment processing",
      body: "Your payment is processing. Some payment methods take a few days. We'll email your key as soon as it clears.",
      confirmed: false,
    };
  }
  return {
    kind: "unknown",
    heading: "We couldn't confirm this yet",
    body: `We couldn't confirm this yet. Email ${SUPPORT_EMAIL} and we'll sort it out.`,
    confirmed: false,
  };
}

export function interpretResponse(httpStatus: number, payload: Record<string, unknown> | null): CheckoutView {
  const dumped = JSON.stringify(payload ?? {});
  if (
    payload &&
    ("license_key" in payload || "token" in payload || "encrypted_key" in payload || /PRUNE-[0-9A-HJKMNP-TV-Z]{5}-/i.test(dumped))
  ) {
    return { payment_state: "unknown", delivery_state: "unknown", email_masked: null };
  }
  if (httpStatus !== 200) {
    return { payment_state: "unknown", delivery_state: "unknown", email_masked: null };
  }
  const payment = typeof payload?.payment_state === "string" ? payload.payment_state : "unknown";
  const delivery = typeof payload?.delivery_state === "string" ? payload.delivery_state : "unknown";
  const email = typeof payload?.email_masked === "string" ? payload.email_masked : null;
  return { payment_state: payment, delivery_state: delivery, email_masked: email };
}
