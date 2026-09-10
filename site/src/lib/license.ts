import { PRODUCT } from "@/lib/product";

const LICENSE_KEY = "diskprune.license";

export function isValidFormat(key: string): boolean {
  return key.trim().toUpperCase() === PRODUCT.demoKey;
}

export function normalizeKey(key: string): string {
  return key.trim().toUpperCase();
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

/** Web-demo verification only. The native app verifies Ed25519 DPL tokens. */
export function verifyLicense(key: string): boolean {
  return normalizeKey(key) === PRODUCT.demoKey;
}
