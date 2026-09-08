#!/usr/bin/env node
/**
 * Validates /shared/storage-rules.json against the handoff constraints.
 * No extra npm dependency — hand-rolled so CI job 4 has zero install.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const file = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.join(root, "shared", "storage-rules.json");

const CATEGORIES = new Set([
  "developerBuild",
  "packageCache",
  "applicationCache",
  "log",
  "applicationSupport",
  "containerData",
  "virtualDisk",
  "snapshot",
  "application",
  "userData",
  "unknown",
]);
const SAFETY = new Set(["safe", "review", "advanced", "protected"]);
const ID_RE = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const PATH_RE = /^(\/|~\/).+/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const MACOS_RE = /^\d+\.\d+$/;
const RULE_KEYS = new Set([
  "id",
  "paths",
  "envOverride",
  "displayName",
  "category",
  "safety",
  "regenerable",
  "producer",
  "explanation",
  "consequence",
  "howItComesBack",
  "minMacOS",
  "docsURL",
  "lastReviewed",
  "publish",
]);
const ROOT_KEYS = new Set(["schemaVersion", "rulesVersion", "rules", "generated", "source"]);

const errors = [];
const fail = (msg) => errors.push(msg);

const raw = fs.readFileSync(file, "utf8");
let data;
try {
  data = JSON.parse(raw);
} catch (err) {
  console.error(`Invalid JSON: ${err.message}`);
  process.exit(1);
}

if (typeof data !== "object" || data === null || Array.isArray(data)) {
  fail("root must be an object");
} else {
  for (const k of Object.keys(data)) {
    if (!ROOT_KEYS.has(k)) fail(`root additional property: ${k}`);
  }
  if (data.schemaVersion !== 1) fail("schemaVersion must be 1");
  if (typeof data.rulesVersion !== "string" || !data.rulesVersion) fail("rulesVersion required");
  if (!Array.isArray(data.rules) || data.rules.length < 1) fail("rules must be a non-empty array");
}

const ids = new Set();
for (const [i, rule] of (data.rules || []).entries()) {
  const loc = `rules[${i}]`;
  if (typeof rule !== "object" || rule === null) {
    fail(`${loc} must be an object`);
    continue;
  }
  for (const k of Object.keys(rule)) {
    if (!RULE_KEYS.has(k)) fail(`${loc} additional property: ${k}`);
  }
  if (!ID_RE.test(rule.id || "")) fail(`${loc}.id invalid: ${rule.id}`);
  if (ids.has(rule.id)) fail(`duplicate id: ${rule.id}`);
  ids.add(rule.id);
  if (!Array.isArray(rule.paths) || rule.paths.length < 1) fail(`${loc}.paths must have ≥1 entry`);
  else {
    for (const p of rule.paths) {
      if (!PATH_RE.test(p)) fail(`${loc}.paths invalid: ${p}`);
    }
  }
  if (rule.envOverride !== undefined && (typeof rule.envOverride !== "string" || !rule.envOverride)) {
    fail(`${loc}.envOverride must be a non-empty string when present`);
  }
  if (typeof rule.displayName !== "string" || !rule.displayName) fail(`${loc}.displayName required`);
  if (!CATEGORIES.has(rule.category)) fail(`${loc}.category invalid: ${rule.category}`);
  if (!SAFETY.has(rule.safety)) fail(`${loc}.safety invalid: ${rule.safety}`);
  if (typeof rule.regenerable !== "boolean") fail(`${loc}.regenerable must be boolean`);
  if (typeof rule.producer !== "string" || !rule.producer) fail(`${loc}.producer required`);
  if (typeof rule.explanation !== "string" || rule.explanation.length < 40) {
    fail(`${loc}.explanation must be ≥40 chars`);
  }
  if (typeof rule.consequence !== "string" || rule.consequence.length < 40) {
    fail(`${loc}.consequence must be ≥40 chars`);
  }
  if (rule.regenerable === true) {
    if (typeof rule.howItComesBack !== "string" || !rule.howItComesBack) {
      fail(`${loc}.howItComesBack required when regenerable is true`);
    }
  }
  if (!MACOS_RE.test(rule.minMacOS || "")) fail(`${loc}.minMacOS invalid`);
  if (!("docsURL" in rule)) fail(`${loc}.docsURL key must be present (https URL or null)`);
  else if (rule.docsURL !== null && !(typeof rule.docsURL === "string" && rule.docsURL.startsWith("https://"))) {
    fail(`${loc}.docsURL must be https://… or null`);
  }
  if (!DATE_RE.test(rule.lastReviewed || "")) fail(`${loc}.lastReviewed must be YYYY-MM-DD`);
  if (typeof rule.publish !== "boolean") fail(`${loc}.publish must be boolean`);
  if (rule.safety === "protected" && rule.publish !== false) {
    fail(`${loc} protected rules must have publish: false`);
  }
}

if (errors.length) {
  console.error(`validation failed (${errors.length}):`);
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}
console.log(`OK ${file} (${ids.size} rules, version ${data.rulesVersion})`);
