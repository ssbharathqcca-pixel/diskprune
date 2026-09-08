import { create } from "zustand";
import {
  ALL_CATEGORIES,
  SCAN_ORDER,
  SNAPSHOTS,
  type ScanCategory,
} from "@/lib/scan-data";
import {
  getStoredLicense,
  saveLicense,
  verifyLicense,
} from "@/lib/license";
import { prefersReducedMotion } from "@/lib/utils";

export type Phase = "idle" | "scanning" | "ready" | "purging" | "done";
export type NavPane = "dashboard" | "tier1" | "tier2" | "license";

export type FoundItem = ScanCategory & {
  selected: boolean;
  status: "found" | "purged" | "skipped";
};

type PruneState = {
  phase: Phase;
  progress: number;
  scanLabel: string;
  items: FoundItem[];
  snapshotBytes: number;
  snapshotCount: number;
  flushSnapshots: boolean;
  snapshotsFlushed: boolean;
  pane: NavPane;
  licenseKey: string;
  activated: boolean;
  showLicense: boolean;
  licenseError: string | null;
  lastFreed: number;
  startScan: () => void;
  toggleItem: (id: string) => void;
  setFlushSnapshots: (value: boolean) => void;
  requestPurge: () => void;
  confirmPurge: () => void;
  activate: (key: string) => boolean;
  setPane: (pane: NavPane) => void;
  setShowLicense: (open: boolean) => void;
  reset: () => void;
  hydrateLicense: () => void;
};

let scanTimer: ReturnType<typeof setTimeout> | null = null;
let purgeTimer: ReturnType<typeof setTimeout> | null = null;

function clearTimers() {
  if (scanTimer) clearTimeout(scanTimer);
  if (purgeTimer) clearTimeout(purgeTimer);
  scanTimer = null;
  purgeTimer = null;
}

function selectedBytes(items: FoundItem[], snapshotBytes: number, flush: boolean) {
  const files = items
    .filter((i) => i.selected && i.status !== "purged")
    .reduce((sum, i) => sum + i.bytes, 0);
  return files + (flush ? snapshotBytes : 0);
}

export const usePruneStore = create<PruneState>((set, get) => ({
  phase: "idle",
  progress: 0,
  scanLabel: "",
  items: [],
  snapshotBytes: 0,
  snapshotCount: 0,
  flushSnapshots: true,
  snapshotsFlushed: false,
  pane: "dashboard",
  licenseKey: "",
  activated: false,
  showLicense: false,
  licenseError: null,
  lastFreed: 0,

  hydrateLicense: () => {
    const stored = getStoredLicense();
    if (stored && verifyLicense(stored)) {
      set({ activated: true, licenseKey: stored });
    }
  },

  setPane: (pane) => set({ pane }),
  setShowLicense: (open) => set({ showLicense: open, licenseError: null }),
  setFlushSnapshots: (value) => set({ flushSnapshots: value }),

  toggleItem: (id) =>
    set((state) => ({
      items: state.items.map((item) =>
        item.id === id && item.status !== "purged"
          ? { ...item, selected: !item.selected }
          : item,
      ),
    })),

  startScan: () => {
    clearTimers();
    set({
      phase: "scanning",
      progress: 0,
      scanLabel: "Starting enumerator…",
      items: [],
      snapshotBytes: 0,
      snapshotCount: 0,
      snapshotsFlushed: false,
      lastFreed: 0,
      pane: "dashboard",
    });

    const reduced = prefersReducedMotion();
    const steps = SCAN_ORDER.length;

    const finish = () => {
      set({
        phase: "ready",
        progress: 100,
        scanLabel: "Scan complete",
        items: ALL_CATEGORIES.map((c) => ({
          ...c,
          selected: c.tier === 1,
          status: "found" as const,
        })),
        snapshotBytes: SNAPSHOTS.bytes,
        snapshotCount: SNAPSHOTS.count,
      });
    };

    if (reduced) {
      finish();
      return;
    }

    let step = 0;
    const tick = () => {
      step += 1;
      const label = SCAN_ORDER[step - 1] ?? "Finishing…";
      const revealed = ALL_CATEGORIES.slice(0, Math.min(step, ALL_CATEGORIES.length)).map(
        (c) => ({
          ...c,
          selected: c.tier === 1,
          status: "found" as const,
        }),
      );
      const snaps =
        step >= SCAN_ORDER.length
          ? { snapshotBytes: SNAPSHOTS.bytes, snapshotCount: SNAPSHOTS.count }
          : {};
      set({
        progress: Math.round((step / steps) * 100),
        scanLabel: label,
        items: revealed,
        ...snaps,
      });
      if (step < steps) {
        scanTimer = setTimeout(tick, 220);
      } else {
        set({ phase: "ready", scanLabel: "Scan complete" });
      }
    };
    scanTimer = setTimeout(tick, 180);
  },

  requestPurge: () => {
    const { activated, items, phase } = get();
    if (phase !== "ready") return;
    const hasSelection = items.some((i) => i.selected);
    if (!hasSelection && !get().flushSnapshots) return;
    if (!activated) {
      set({ showLicense: true, licenseError: null, pane: "license" });
      return;
    }
    get().confirmPurge();
  },

  confirmPurge: () => {
    const { items, flushSnapshots, snapshotBytes } = get();
    const freed = selectedBytes(items, snapshotBytes, flushSnapshots);
    set({ phase: "purging", scanLabel: "Moving items to Trash…" });

    const finish = () => {
      set((state) => ({
        phase: "done",
        scanLabel: "Purge complete",
        items: state.items.map((item) =>
          item.selected
            ? { ...item, status: "purged" as const, selected: false }
            : { ...item, status: "skipped" as const },
        ),
        snapshotBytes: state.flushSnapshots ? 0 : state.snapshotBytes,
        snapshotCount: state.flushSnapshots ? 0 : state.snapshotCount,
        snapshotsFlushed: state.flushSnapshots,
        lastFreed: freed,
      }));
    };

    if (prefersReducedMotion()) {
      finish();
      return;
    }
    purgeTimer = setTimeout(finish, 1100);
  },

  activate: (key) => {
    if (!verifyLicense(key)) {
      set({ licenseError: "Invalid license key.", activated: false });
      return false;
    }
    saveLicense(key);
    const ready = get().phase === "ready";
    set({
      activated: true,
      licenseKey: key.trim().toUpperCase(),
      licenseError: null,
      showLicense: false,
      pane: ready ? "dashboard" : get().pane,
    });
    if (ready) {
      get().confirmPurge();
    }
    return true;
  },

  reset: () => {
    clearTimers();
    set({
      phase: "idle",
      progress: 0,
      scanLabel: "",
      items: [],
      snapshotBytes: 0,
      snapshotCount: 0,
      flushSnapshots: true,
      snapshotsFlushed: false,
      lastFreed: 0,
      pane: "dashboard",
    });
  },
}));

export function reclaimable(state: Pick<PruneState, "items" | "snapshotBytes" | "flushSnapshots" | "phase">) {
  if (state.phase === "idle") return 0;
  const live = state.items.filter((i) => i.status !== "purged");
  const files = live.filter((i) => i.selected).reduce((sum, i) => sum + i.bytes, 0);
  const snaps = state.flushSnapshots ? state.snapshotBytes : 0;
  return files + snaps;
}
