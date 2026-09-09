async function bump(kv, key, limit, ttl) {
  if (!kv) return { ok: true, remaining: limit };
  const current = Number((await kv.get(key)) || "0");
  if (current >= limit) return { ok: false, remaining: 0 };
  await kv.put(key, String(current + 1), { expirationTtl: ttl });
  return { ok: true, remaining: limit - current - 1 };
}

export async function limitIp(env, name, ip, limit, ttl = 3600) {
  const addr = ip || "unknown";
  return bump(env.RATE_LIMITS, `rl:ip:${name}:${addr}`, limit, ttl);
}

export async function limitKey(env, name, value, limit, ttl = 3600) {
  return bump(env.RATE_LIMITS, `rl:${name}:${value}`, limit, ttl);
}

export function clientIp(request) {
  return request.headers.get("CF-Connecting-IP") || request.headers.get("X-Forwarded-For")?.split(",")[0]?.trim() || "unknown";
}
