import { test } from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { COMPARISON } from "../src/lib/product.mjs";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const SRC = join(ROOT, "src");

function walk(dir, acc = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, acc);
    else if (/\.(astro|mjs|css|md)$/.test(name)) acc.push(p);
  }
  return acc;
}

const files = walk(SRC).map((p) => ({
  path: p.slice(SRC.length + 1),
  text: readFileSync(p, "utf8"),
}));
const blob = files.map((f) => f.text).join("\n");

test("marketing copy does not promise snapshot flushing", () => {
  assert.equal(/snapshot flushing/i.test(blob), false);
  assert.equal(/flush APFS/i.test(blob), false);
  assert.equal(/Flush APFS snapshots/i.test(blob), false);
});

test("homepage no longer uses Reclaim Gigabytes", () => {
  assert.equal(/Reclaim Gigabytes/i.test(blob), false);
});

test("comparison table does not invent DiskBuddy or DissectMac billing", () => {
  const buddy = COMPARISON.rows.find((r) => r.feature === "Price");
  assert.ok(buddy);
  assert.equal(/subscription/i.test(buddy.diskbuddy), false);
  assert.match(buddy.diskbuddy, /lifetime/i);
  assert.match(buddy.dissectmac, /free/i);
  assert.equal(/subscription/i.test(buddy.dissectmac), false);
  assert.match(buddy.diskprune, /\$19/);
  assert.match(buddy.cleanmymac, /subscription/i);
});

test("comparison does not call DiskBuddy Shortcuts-based", () => {
  assert.equal(/shortcuts based/i.test(blob), false);
});

test("cleanup marketing does not call trashed bytes freed or reclaimed", () => {
  const offenders = [];
  for (const f of files) {
    if (/\bfreed\b|\breclaimed\b|\breclaim\b/i.test(f.text)) {
      offenders.push(f.path);
    }
  }
  assert.deepEqual(offenders, []);
});

test("guides exist for System Data, DerivedData, Docker, purgeable", () => {
  const slugs = [
    "clear-system-data-mac",
    "how-to-delete-xcode-deriveddata",
    "shrink-docker-disk-mac",
    "delete-purgeable-space-mac",
  ];
  const blog = readFileSync(join(SRC, "pages/blog/[slug].astro"), "utf8");
  const guides = readFileSync(join(SRC, "lib/guides.mjs"), "utf8");
  for (const slug of slugs) {
    assert.match(guides, new RegExp(slug));
  }
  assert.match(blog, /GUIDE_PAGES/);
  assert.match(guides, /does not run snapshot deletion|inspect-only|Inspect only/i);
  assert.match(guides, /Protected on purpose/);
});
