export type SafetyTier = 1 | 2;

export type ScanCategory = {
  id: string;
  path: string;
  category: string;
  bytes: number;
  files: number;
  tier: SafetyTier;
  note: string;
  samples: string[];
};

/**
 * Mirrors SafetyRules.swift from the native app:
 *   tier1 — caches, logs, Xcode DerivedData, npm / cargo / gradle
 *   tier2 — Containers, Application Support, Docker Desktop
 * Sizes are a simulated developer Mac, not a live disk.
 */
export const TIER1_CATEGORIES: ScanCategory[] = [
  {
    id: "xcode",
    path: "~/Library/Developer/Xcode/DerivedData",
    category: "Xcode DerivedData",
    bytes: 12_430_000_000,
    files: 18420,
    tier: 1,
    note: "Build products and indexes. Safe to clear; Xcode rebuilds on next compile.",
    samples: [
      "~/Library/Developer/Xcode/DerivedData/DiskPrune-ekqjxw",
      "~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex",
      "~/Library/Developer/Xcode/DerivedData/SDKStatCaches.noindex",
    ],
  },
  {
    id: "user-caches",
    path: "~/Library/Caches",
    category: "User caches",
    bytes: 4_812_000_000,
    files: 9204,
    tier: 1,
    note: "App caches under your home folder. Recreated as needed.",
    samples: [
      "~/Library/Caches/com.apple.helpd",
      "~/Library/Caches/Homebrew",
      "~/Library/Caches/com.spotify.client",
    ],
  },
  {
    id: "npm",
    path: "~/.npm/_cacache",
    category: "npm cache",
    bytes: 3_240_000_000,
    files: 44102,
    tier: 1,
    note: "Content-addressable npm tarball cache. Equivalent to npm cache clean --force.",
    samples: ["~/.npm/_cacache/content-v2", "~/.npm/_cacache/index-v5"],
  },
  {
    id: "gradle",
    path: "~/.gradle/caches",
    category: "Gradle caches",
    bytes: 2_110_000_000,
    files: 8733,
    tier: 1,
    note: "Downloaded artifacts and transform caches for Android / JVM builds.",
    samples: ["~/.gradle/caches/modules-2", "~/.gradle/caches/transforms-4"],
  },
  {
    id: "cargo",
    path: "~/.cargo/registry/cache",
    category: "Cargo registry",
    bytes: 1_720_000_000,
    files: 2104,
    tier: 1,
    note: "Cached crate tarballs. cargo fetch will refill them.",
    samples: ["~/.cargo/registry/cache/index.crates.io-6f17d22bba15001f"],
  },
  {
    id: "user-logs",
    path: "~/Library/Logs",
    category: "User logs",
    bytes: 640_000_000,
    files: 388,
    tier: 1,
    note: "Diagnostic logs in your home folder.",
    samples: ["~/Library/Logs/CoreSimulator", "~/Library/Logs/DiagnosticReports"],
  },
  {
    id: "system-logs",
    path: "/Library/Logs",
    category: "System logs",
    bytes: 290_000_000,
    files: 142,
    tier: 1,
    note: "Machine-wide logs. Requires Full Disk Access on a real Mac.",
    samples: ["/Library/Logs/DiagnosticReports", "/Library/Logs/Software Update"],
  },
];

export const TIER2_CATEGORIES: ScanCategory[] = [
  {
    id: "docker",
    path: "~/.docker/desktop",
    category: "Docker Desktop",
    bytes: 28_610_000_000,
    files: 4,
    tier: 2,
    note: "Docker.raw disk image. Review — shrinking is safer than deleting the app.",
    samples: ["~/.docker/desktop/vms/0/data/Docker.raw"],
  },
  {
    id: "containers",
    path: "~/Library/Containers",
    category: "App containers",
    bytes: 8_140_000_000,
    files: 612,
    tier: 2,
    note: "Sandboxed app data. Review before sending anything to Trash.",
    samples: [
      "~/Library/Containers/com.docker.docker",
      "~/Library/Containers/com.apple.Safari",
    ],
  },
  {
    id: "appsupport",
    path: "~/Library/Application Support",
    category: "Application Support",
    bytes: 6_330_000_000,
    files: 2401,
    tier: 2,
    note: "May contain live app databases. Only orphaned folders should be purged.",
    samples: [
      "~/Library/Application Support/Code",
      "~/Library/Application Support/Caches",
    ],
  },
];

export const ALL_CATEGORIES: ScanCategory[] = [
  ...TIER1_CATEGORIES,
  ...TIER2_CATEGORIES,
];

export const SNAPSHOTS = {
  bytes: 14_200_000_000,
  count: 7,
  command: "tmutil deletelocalsnapshots /",
} as const;

export const SCAN_ORDER = [
  ...TIER1_CATEGORIES.map((c) => c.path),
  ...TIER2_CATEGORIES.map((c) => c.path),
  "APFS local snapshots",
];
