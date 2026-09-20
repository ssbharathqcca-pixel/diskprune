/** Status-only checkout page. Never handles a license key. */

export const API_ORIGIN = "https://api.diskprune.com";
export const SUPPORT_EMAIL = "support@diskprune.com";
export const DOWNLOAD_URL = "https://diskprune.com/download";
export const POLL_LIMIT = 3;
export const POLL_MS = 2000;
export const SESSION_RE = /^cs_[A-Za-z0-9_]{6,250}$/;

const FORBIDDEN_RESPONSE_KEYS = [
  "license_key",
  "licenseKey",
  "key",
  "token",
  "encrypted_key",
  "plaintext",
];

export function parseSessionId(search) {
  const q = String(search || "");
  const raw = q.startsWith("?") ? q.slice(1) : q;
  const value = new URLSearchParams(raw).get("session_id");
  if (!value || !SESSION_RE.test(value)) return null;
  return value;
}

export function statusUrl(sessionId) {
  return `${API_ORIGIN}/v1/checkout/${encodeURIComponent(sessionId)}/status`;
}

export function payloadLeaksSecret(payload) {
  if (payload == null) return false;
  if (typeof payload !== "object") {
    return /PRUNE-[0-9A-HJKMNP-TV-Z]{5}-/i.test(String(payload));
  }
  for (const key of FORBIDDEN_RESPONSE_KEYS) {
    if (Object.prototype.hasOwnProperty.call(payload, key)) return true;
  }
  return /PRUNE-[0-9A-HJKMNP-TV-Z]{5}-/i.test(JSON.stringify(payload));
}

export function interpretResponse(httpStatus, payload) {
  const safe = payload && typeof payload === "object" ? payload : {};
  if (payloadLeaksSecret(safe)) {
    return { httpStatus, payment_state: "unknown", delivery_state: "unknown", email_masked: null };
  }
  if (httpStatus !== 200) {
    return { httpStatus, payment_state: "unknown", delivery_state: "unknown", email_masked: null };
  }
  return {
    httpStatus,
    payment_state: typeof safe.payment_state === "string" ? safe.payment_state : "unknown",
    delivery_state: typeof safe.delivery_state === "string" ? safe.delivery_state : "unknown",
    email_masked: typeof safe.email_masked === "string" ? safe.email_masked : null,
  };
}

export function shouldPoll(view) {
  return view.payment_state === "paid" && view.delivery_state === "pending" && !view.pollExhausted;
}

export function copyFor(view) {
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

export function loadingCopy() {
  return "Checking payment status…";
}

export async function fetchStatus(sessionId, fetchImpl) {
  const res = await fetchImpl(statusUrl(sessionId), {
    method: "GET",
    headers: { Accept: "application/json" },
    credentials: "omit",
  });
  let payload = {};
  try {
    payload = await res.json();
  } catch {
    payload = {};
  }
  return interpretResponse(res.status, payload);
}

export async function resolveCheckoutStatus(sessionId, { fetchImpl, sleep } = {}) {
  const fetchFn = fetchImpl;
  const wait = sleep || ((ms) => new Promise((resolve) => setTimeout(resolve, ms)));
  let view = await fetchStatus(sessionId, fetchFn);
  let polls = 0;
  while (shouldPoll(view) && polls < POLL_LIMIT) {
    await wait(POLL_MS);
    polls += 1;
    view = await fetchStatus(sessionId, fetchFn);
  }
  if (shouldPoll(view)) view = { ...view, pollExhausted: true };
  return view;
}

export async function mountSuccessPage({
  document: doc,
  search,
  fetchImpl,
  sleep,
} = {}) {
  const heading = doc.getElementById("status-heading");
  const body = doc.getElementById("status-body");
  const loading = doc.getElementById("status-loading");
  const sessionId = parseSessionId(search || "");

  const render = (view) => {
    const copy = copyFor(view);
    if (heading) heading.textContent = copy.heading;
    if (body) body.textContent = copy.body;
    if (loading) loading.hidden = true;
  };

  if (!sessionId) {
    render({ payment_state: "unknown", delivery_state: "unknown", email_masked: null });
    return { kind: "unknown", sessionId: null };
  }

  const view = await resolveCheckoutStatus(sessionId, { fetchImpl, sleep });
  render(view);
  return { kind: copyFor(view).kind, sessionId, view };
}
