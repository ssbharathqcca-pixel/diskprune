import { handleWebhook } from "./webhook.js";
import {
  handleActivate,
  handleCheckoutStatus,
  handleRefresh,
  handleRelease,
  handleResend,
} from "./licenses.js";
import { clientIp, limitIp } from "./ratelimit.js";
import { retryFailedEmails } from "./email.js";

const DEFAULT_ORIGIN = "https://diskprune.com";

function corsHeaders(env) {
  const allow = env.CORS_ORIGIN || DEFAULT_ORIGIN;
  return {
    "Access-Control-Allow-Origin": allow,
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    Vary: "Origin",
  };
}

function withCors(response, env) {
  const headers = new Headers(response.headers);
  const extra = corsHeaders(env);
  for (const [k, v] of Object.entries(extra)) headers.set(k, v);
  return new Response(response.body, { status: response.status, headers });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(env) });
    }

    let response;
    if (request.method === "POST" && url.pathname === "/webhook") {
      response = await handleWebhook(request, env);
    } else if (request.method === "POST" && url.pathname === "/v1/licenses/activate") {
      response = await handleActivate(request, env);
    } else if (request.method === "POST" && url.pathname === "/v1/licenses/refresh") {
      response = await handleRefresh(request, env);
    } else if (request.method === "POST" && url.pathname === "/v1/licenses/release") {
      response = await handleRelease(request, env);
    } else if (request.method === "POST" && url.pathname === "/v1/licenses/resend") {
      response = await handleResend(request, env);
    } else if (request.method === "GET" && url.pathname.startsWith("/v1/checkout/") && url.pathname.endsWith("/status")) {
      const ip = clientIp(request);
      if (!(await limitIp(env, "checkout-status", ip, 30)).ok) {
        response = new Response(JSON.stringify({ error: "RATE_LIMIT" }), {
          status: 429,
          headers: { "Content-Type": "application/json" },
        });
      } else {
        const sessionId = url.pathname.slice("/v1/checkout/".length, -"/status".length);
        response = await handleCheckoutStatus(sessionId, env);
      }
    } else {
      response = new Response("Not Found", { status: 404 });
    }
    return withCors(response, env);
  },

  async scheduled(_event, env) {
    await retryFailedEmails(env);
  },
};
