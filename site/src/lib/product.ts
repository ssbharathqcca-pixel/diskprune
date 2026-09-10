export const PRODUCT = {
  name: "DiskPrune",
  tagline: "Reclaim gigabytes on macOS.",
  price: 19,
  priceLabel: "$19",
  os: "macOS 14 Sonoma and later",
  bundleId: "com.diskprune.app",
  stripeUrl: "https://buy.stripe.com/eVqeVc8nd9wx39efNdaR200",
  dmgUrl: "https://diskprune.com/download",
  repoUrl: "https://github.com/ssbharathqcca-pixel/diskprune",
  apiActivate: "https://api.diskprune.com/v1/licenses/activate",
  demoKey: "PRUNE-DEMO-2026-LIFE",
} as const;

export const COMPARISON = [
  {
    feature: "Tech stack",
    diskprune: "Native SwiftUI",
    dissect: "Treemap only",
    buddy: "Shortcuts based",
  },
  {
    feature: "Pricing",
    diskprune: "$19 one-time",
    dissect: "Subscription",
    buddy: "Subscription",
  },
  {
    feature: "APFS snapshots",
    diskprune: "Inspect only — never deleted",
    dissect: "No",
    buddy: "No",
  },
  {
    feature: "Safety model",
    diskprune: "Two-tier review",
    dissect: "Manual select",
    buddy: "Preset scripts",
  },
  {
    feature: "Delete method",
    diskprune: "Moves to Trash",
    dissect: "Varies",
    buddy: "Varies",
  },
  {
    feature: "Scan vs purge",
    diskprune: "Scan free, purge licensed",
    dissect: "Paywalled",
    buddy: "Paywalled",
  },
] as const;
