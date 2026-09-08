import { PRODUCT } from "@/lib/product";

const LICENSE_KEY = "diskprune.license";
const ISSUED_KEY = "diskprune.issued";

const FORMAT = /^PRUNE-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/;

export function isValidFormat(key: string): boolean {
  const trimmed = key.trim().toUpperCase();
  if (trimmed === PRODUCT.demoKey) return true;
  return FORMAT.test(trimmed);
}

export function normalizeKey(key: string): string {
  return key.trim().toUpperCase();
}

function readIssued(): string[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.localStorage.getItem(ISSUED_KEY);
    return raw ? (JSON.parse(raw) as string[]) : [];
  } catch {
    return [];
  }
}

export function issueLicense(): string {
  const seg = () => Math.random().toString(36).slice(2, 6).toUpperCase();
  const key = `PRUNE-${seg()}-${seg()}-${seg()}`;
  if (typeof window !== "undefined") {
    const issued = readIssued();
    issued.push(key);
    window.localStorage.setItem(ISSUED_KEY, JSON.stringify(issued));
  }
  return key;
}

export function getStoredLicense(): string | null {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem(LICENSE_KEY);
}

export function saveLicense(key: string) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(LICENSE_KEY, normalizeKey(key));
}

export function clearLicense() {
  if (typeof window === "undefined") return;
  window.localStorage.removeItem(LICENSE_KEY);
}

/** Web-demo verification. Native app POSTs to api.diskprune.com. */
export function verifyLicense(key: string): boolean {
  const k = normalizeKey(key);
  if (!isValidFormat(k)) return false;
  if (k === PRODUCT.demoKey) return true;
  return readIssued().includes(k);
}
