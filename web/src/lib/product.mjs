/** Public product facts. One source for price, buy URL, and comparison copy. */

export const PRICE = "$19";
export const PRICE_NUMBER = "19.00";
export const SEATS = 3;
export const BUY_URL =
  "https://buy.stripe.com/eVqeVc8nd9wx39efNdaR200";
export const SUPPORT_EMAIL = "support@diskprune.com";
export const LICENSES_EMAIL = "licenses@diskprune.com";
export const SITE_ORIGIN = "https://diskprune.com";

export const TAGLINE =
  "See why your Mac is full. Move only what you approve to Trash.";

export const DESCRIPTION =
  "Native macOS storage intelligence. Scan is free. Cleanup is a $19 lifetime license. Trash only — DiskPrune never empties Trash, never deletes APFS snapshots, and never touches Docker.raw.";

export const PROMISES = [
  "Scan, autopsy, and explanations are free.",
  "Cleanup is a $19 lifetime license for up to 3 Macs.",
  "The only mutation is FileManager.trashItem after a dry run.",
  "DiskPrune never empties Trash, never permanently deletes, and never deletes APFS snapshots.",
  "Docker.raw and Docker data directories are protected.",
];

export const GUIDES = [
  {
    href: "/blog/clear-system-data-mac",
    title: "System Data on Mac is huge",
    blurb: "What that bucket actually contains — and what DiskPrune will not flush.",
  },
  {
    href: "/blog/how-to-delete-xcode-deriveddata",
    title: "Xcode DerivedData",
    blurb: "Named, classed, and moved to Trash only. Xcode rebuilds it.",
  },
  {
    href: "/blog/shrink-docker-disk-mac",
    title: "Docker.raw is eating the disk",
    blurb: "Protected on purpose. Compact it with Docker, not with a cleaner.",
  },
  {
    href: "/blog/delete-purgeable-space-mac",
    title: "Purgeable space and snapshots",
    blurb: "Inspect only. DiskPrune does not run snapshot deletion.",
  },
];

export const COMPARE_PAGES = [
  {
    href: "/mac-disk-space-analyzer",
    title: "Mac disk space analyzers",
    blurb: "DaisyDisk, DiskBuddy, DissectMac, CleanMyMac, and DiskPrune — honest.",
  },
  {
    href: "/vs-cleanmymac",
    title: "DiskPrune vs CleanMyMac",
    blurb: "$19 lifetime and Trash-only, versus a subscription suite.",
  },
];

/** Rows for the public comparison table. Values are current as of September 2026. */
export const COMPARISON = {
  columns: [
    { id: "diskprune", name: "DiskPrune" },
    { id: "daisydisk", name: "DaisyDisk" },
    { id: "diskbuddy", name: "DiskBuddy" },
    { id: "dissectmac", name: "DissectMac" },
    { id: "cleanmymac", name: "CleanMyMac" },
  ],
  rows: [
    {
      feature: "Price",
      diskprune: "$19 lifetime",
      daisydisk: "~$9.99 lifetime, 5 Macs",
      diskbuddy: "$9 launch / $49 list, lifetime",
      dissectmac: "Free",
      cleanmymac: "Subscription",
    },
    {
      feature: "Native Mac app",
      diskprune: "SwiftUI, macOS 14+",
      daisydisk: "Yes",
      diskbuddy: "Yes",
      dissectmac: "Yes",
      cleanmymac: "Yes",
    },
    {
      feature: "Notarized",
      diskprune: "Not yet — Open Anyway until Gate 5",
      daisydisk: "Yes",
      diskbuddy: "No (unsigned as of Sep 2026)",
      dissectmac: "Yes",
      cleanmymac: "Yes",
    },
    {
      feature: "How you see the disk",
      diskprune: "Storage autopsy + categories",
      daisydisk: "Sunburst (category-defining)",
      diskbuddy: "Eight charts",
      dissectmac: "Treemap",
      cleanmymac: "Dashboard",
    },
    {
      feature: "Explains why bytes exist",
      diskprune: "Core product",
      daisydisk: "Weak",
      diskbuddy: "Weak",
      dissectmac: "Weak",
      cleanmymac: "Marketing copy",
    },
    {
      feature: "Cleanup",
      diskprune: "Plan → dry run → TOCTOU → Trash → receipt",
      daisydisk: "Collector",
      diskbuddy: "Staged claims",
      dissectmac: "None",
      cleanmymac: "Aggressive",
    },
    {
      feature: "APFS snapshots",
      diskprune: "Inspect only",
      daisydisk: "Shows hidden space",
      diskbuddy: "Marketing claim",
      dissectmac: "No",
      cleanmymac: "Often overclaims",
    },
    {
      feature: "Docker.raw",
      diskprune: "Protected",
      daisydisk: "Not a promise",
      diskbuddy: "Not a promise",
      dissectmac: "Not a promise",
      cleanmymac: "Risk",
    },
    {
      feature: "Permanent delete",
      diskprune: "Architecturally forbidden",
      daisydisk: "User-driven",
      diskbuddy: "Claims staged",
      dissectmac: "n/a",
      cleanmymac: "Yes",
    },
    {
      feature: "Scan",
      diskprune: "Free",
      daisydisk: "Paid app",
      diskbuddy: "Paid app",
      dissectmac: "Free",
      cleanmymac: "Limited without subscription",
    },
  ],
};
