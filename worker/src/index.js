function randomSegment(length) {
  const alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  let out = "";
  for (let i = 0; i < length; i++) {
    out += alphabet[bytes[i] % alphabet.length];
  }
  return out;
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      });
    }

    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Content-Type": "application/json"
    };

    if (request.method === 'POST' && url.pathname === '/webhook') {
      try {
        const payload = await request.json();
        if (payload.type === 'checkout.session.completed') {
          const session = payload.data.object;
          const email = session.customer_details?.email || 'unknown';
          const sessionId = session.id;

          const licenseKey = `PRUNE-${randomSegment(4)}-${randomSegment(4)}-${randomSegment(4)}`;

          // Store in KV
          await env.LICENSES.put(licenseKey, JSON.stringify({ email, active: true }));

          // Store session mapping so the success page can retrieve it later
          await env.LICENSES.put(`session:${sessionId}`, JSON.stringify({ licenseKey }));

          return new Response(JSON.stringify({ received: true }), { status: 200, headers: corsHeaders });
        }
        return new Response(JSON.stringify({ received: true }), { status: 200, headers: corsHeaders });
      } catch (err) {
        return new Response(JSON.stringify({ error: err.message }), { status: 400, headers: corsHeaders });
      }
    }

    if (request.method === 'POST' && url.pathname === '/v1/licenses/activate') {
      try {
        const { license_key } = await request.json();
        const data = await env.LICENSES.get(license_key);

        if (data) {
          const license = JSON.parse(data);
          if (license.active) {
            return new Response(JSON.stringify({ valid: true }), { status: 200, headers: corsHeaders });
          }
        }
        return new Response(JSON.stringify({ valid: false, error: "Invalid key" }), { status: 400, headers: corsHeaders });
      } catch (err) {
        return new Response(JSON.stringify({ valid: false, error: "Invalid request" }), { status: 400, headers: corsHeaders });
      }
    }

    if (request.method === 'GET' && url.pathname === '/key-lookup') {
      const sessionId = url.searchParams.get('session_id');
      if (!sessionId) {
        return new Response(JSON.stringify({ error: "Missing session_id" }), { status: 400, headers: corsHeaders });
      }

      const sessionData = await env.LICENSES.get(`session:${sessionId}`);
      if (sessionData) {
        const { licenseKey } = JSON.parse(sessionData);
        return new Response(JSON.stringify({ license_key: licenseKey }), { status: 200, headers: corsHeaders });
      }
      return new Response(JSON.stringify({ error: "Not found" }), { status: 404, headers: corsHeaders });
    }

    return new Response("Not Found", { status: 404 });
  },
};
