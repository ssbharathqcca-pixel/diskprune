import { decryptLicenseKey } from "./crypto.js";
import { failedEmails, setEmailState, updateEncryptedKey } from "./db.js";

function emailBodies(plaintext, env) {
  const download = env.DOWNLOAD_URL || "https://github.com/ssbharathqcca-pixel/diskprune/releases/latest";
  const support = env.SUPPORT_URL || "https://diskprune.com/support";
  const refunds = env.REFUND_URL || "https://diskprune.com/refunds";
  const text = [
    "Your DiskPrune license key",
    "",
    plaintext,
    "",
    "Activate it in DiskPrune → License → paste the key.",
    `Download: ${download}`,
    `Support: ${support}`,
    `Refunds: ${refunds}`,
    "",
    "Keep this email. DiskPrune never puts the key in a URL or in the browser.",
  ].join("\n");
  const html = `<p>Your DiskPrune license key</p><p><code>${plaintext}</code></p><p>Activate it in DiskPrune → License → paste the key.</p><p><a href="${download}">Download DiskPrune</a></p><p><a href="${support}">Support</a> · <a href="${refunds}">Refund policy</a></p>`;
  return { text, html };
}

export async function sendLicenseEmail(env, licenseRow) {
  const { plaintext, reencrypted } = await decryptLicenseKey(licenseRow.encrypted_key, licenseRow.id, env);
  if (reencrypted) await updateEncryptedKey(env.DB, licenseRow.id, reencrypted);
  const from = env.LICENSE_FROM_EMAIL || "DiskPrune <licenses@diskprune.com>";
  const { text, html } = emailBodies(plaintext, env);
  const res = await (env.fetchImpl || fetch)("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [licenseRow.email],
      subject: "Your DiskPrune license key",
      text,
      html,
    }),
  });
  const attempts = Number(licenseRow.email_attempts || 0) + 1;
  if (res.ok) {
    await setEmailState(env.DB, licenseRow.id, "sent", attempts);
    return { ok: true };
  }
  await setEmailState(env.DB, licenseRow.id, "failed", attempts);
  return { ok: false, status: res.status };
}

export async function retryFailedEmails(env) {
  const rows = await failedEmails(env.DB);
  for (const row of rows) {
    const last = Number(row.email_last_attempt_at || 0);
    const delay = Math.min(6 * 3600 * (2 ** Math.max(0, Number(row.email_attempts || 1) - 1)), 7 * 24 * 3600);
    if (Date.now() / 1000 - last < delay) continue;
    await sendLicenseEmail(env, row);
  }
}
