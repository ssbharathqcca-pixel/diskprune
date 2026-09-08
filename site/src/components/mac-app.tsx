import { useEffect, useMemo } from "react";
import {
  HardDrive,
  KeyRound,
  LayoutDashboard,
  ShieldAlert,
  FolderOpen,
  ScanSearch,
  Trash2,
  RotateCcw,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { Badge } from "@/components/ui/badge";
import { DiskRing } from "@/components/disk-ring";
import { LicenseDialog } from "@/components/license-dialog";
import { PruneMark } from "@/components/wordmark";
import { cn, formatBytes } from "@/lib/utils";
import { PRODUCT } from "@/lib/product";
import { SNAPSHOTS } from "@/lib/scan-data";
import {
  reclaimable,
  usePruneStore,
  type FoundItem,
  type NavPane,
} from "@/lib/prune-store";

const NAV: { id: NavPane; label: string; icon: typeof LayoutDashboard }[] = [
  { id: "dashboard", label: "Dashboard", icon: LayoutDashboard },
  { id: "tier1", label: "Caches · Tier 1", icon: FolderOpen },
  { id: "tier2", label: "Review · Tier 2", icon: ShieldAlert },
  { id: "license", label: "License", icon: KeyRound },
];

export function MacApp({ variant = "hero" }: { variant?: "hero" | "full" }) {
  const hydrateLicense = usePruneStore((s) => s.hydrateLicense);
  const pane = usePruneStore((s) => s.pane);
  const setPane = usePruneStore((s) => s.setPane);

  useEffect(() => {
    hydrateLicense();
  }, [hydrateLicense]);

  return (
    <div
      className={cn(
        "flex flex-col overflow-hidden rounded-xl bg-card text-card-foreground shadow-[var(--shadow-window)]",
        variant === "full" ? "min-h-[720px] h-[min(860px,calc(100dvh-7rem))]" : "h-[min(520px,68dvh)]",
      )}
    >
      <TitleBar />
      <div className="flex min-h-0 flex-1">
        <aside className="hidden w-52 shrink-0 flex-col border-r border-border bg-background/40 md:flex">
          <div className="px-3 py-3">
            <p className="px-2 text-[10px] font-medium uppercase tracking-widest text-faint">
              DiskPrune
            </p>
          </div>
          <nav className="flex flex-1 flex-col gap-0.5 px-2">
            {NAV.map((item) => {
              const Icon = item.icon;
              const active = pane === item.id;
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => setPane(item.id)}
                  className={cn(
                    "flex h-10 items-center gap-2 rounded-md px-2 text-left text-sm transition-colors duration-150",
                    active
                      ? "bg-secondary text-foreground"
                      : "text-muted-foreground hover:bg-secondary/60 hover:text-foreground",
                  )}
                >
                  <Icon className="size-4" />
                  {item.label}
                </button>
              );
            })}
          </nav>
          <p className="px-4 py-3 text-[11px] leading-snug text-faint">
            Simulated typical developer Mac. Native app reads your disk.
          </p>
        </aside>

        <div className="flex min-w-0 flex-1 flex-col">
          <div className="flex gap-1 overflow-x-auto border-b border-border px-2 py-2 md:hidden">
            {NAV.map((item) => (
              <button
                key={item.id}
                type="button"
                onClick={() => setPane(item.id)}
                className={cn(
                  "h-10 shrink-0 rounded-md px-3 text-xs font-medium",
                  pane === item.id
                    ? "bg-secondary text-foreground"
                    : "text-muted-foreground",
                )}
              >
                {item.label}
              </button>
            ))}
          </div>
          <div className="min-h-0 flex-1 overflow-y-auto p-4 sm:p-6">
            {pane === "dashboard" && <DashboardPane />}
            {pane === "tier1" && <CategoryPane tier={1} />}
            {pane === "tier2" && <CategoryPane tier={2} />}
            {pane === "license" && <LicensePane />}
          </div>
        </div>
      </div>
      <LicenseDialog />
    </div>
  );
}

function TitleBar() {
  return (
    <div className="flex h-11 shrink-0 items-center gap-3 border-b border-border px-3">
      <div className="flex gap-1.5" aria-hidden="true">
        <span className="size-3 rounded-full bg-[#ff5f57]" />
        <span className="size-3 rounded-full bg-[#febc2e]" />
        <span className="size-3 rounded-full bg-[#28c840]" />
      </div>
      <div className="flex flex-1 items-center justify-center gap-1.5 text-xs text-muted-foreground">
        <PruneMark className="size-3.5" />
        DiskPrune
      </div>
      <span className="w-14" />
    </div>
  );
}

function DashboardPane() {
  const phase = usePruneStore((s) => s.phase);
  const progress = usePruneStore((s) => s.progress);
  const scanLabel = usePruneStore((s) => s.scanLabel);
  const items = usePruneStore((s) => s.items);
  const snapshotBytes = usePruneStore((s) => s.snapshotBytes);
  const snapshotCount = usePruneStore((s) => s.snapshotCount);
  const flushSnapshots = usePruneStore((s) => s.flushSnapshots);
  const snapshotsFlushed = usePruneStore((s) => s.snapshotsFlushed);
  const lastFreed = usePruneStore((s) => s.lastFreed);
  const startScan = usePruneStore((s) => s.startScan);
  const requestPurge = usePruneStore((s) => s.requestPurge);
  const reset = usePruneStore((s) => s.reset);
  const setFlushSnapshots = usePruneStore((s) => s.setFlushSnapshots);
  const activated = usePruneStore((s) => s.activated);

  const found = reclaimable({ items, snapshotBytes, flushSnapshots, phase });
  const scanning = phase === "scanning";
  const purging = phase === "purging";
  const canPurge =
    phase === "ready" && (items.some((i) => i.selected) || flushSnapshots);

  return (
    <div className="mx-auto flex max-w-lg flex-col items-center gap-4 text-center">
      <div>
        <p className="text-xs font-medium uppercase tracking-widest text-faint">
          {phase === "done" ? "Space reclaimed" : "Space found to free"}
        </p>
        <p className="mt-2 font-mono text-4xl font-medium tracking-tight tabular-nums sm:text-5xl">
          {formatBytes(phase === "done" ? lastFreed : found)}
        </p>
      </div>

      <div className="flex w-full flex-col gap-2 sm:flex-row sm:justify-center">
        {phase === "idle" || phase === "scanning" ? (
          <Button
            size="lg"
            onClick={startScan}
            disabled={scanning}
            className="w-full sm:w-auto"
          >
            <ScanSearch />
            {scanning ? "Scanning…" : "Start scan"}
          </Button>
        ) : null}

        {phase === "ready" || phase === "purging" ? (
          <>
            <Button
              size="lg"
              onClick={requestPurge}
              disabled={!canPurge || purging}
              className="w-full sm:w-auto"
            >
              <Trash2 />
              {purging ? "Purging…" : activated ? "Purge to Trash" : "Purge (license)"}
            </Button>
            <Button size="lg" variant="secondary" onClick={startScan} disabled={purging}>
              Rescan
            </Button>
          </>
        ) : null}

        {phase === "done" ? (
          <Button size="lg" variant="secondary" onClick={reset} className="w-full sm:w-auto">
            <RotateCcw />
            Reset demo
          </Button>
        ) : null}
      </div>

      <DiskRing
        value={phase === "done" ? lastFreed : found}
        label={phase === "idle" ? "Awaiting scan" : phase === "done" ? "Freed" : "Selected"}
      />

      {(scanning || purging) && (
        <div className="w-full space-y-2">
          <Progress value={scanning ? progress : 70} />
          <p className="truncate font-mono text-xs text-muted-foreground">{scanLabel}</p>
        </div>
      )}

      {phase === "ready" && (
        <label className="flex w-full items-start gap-3 rounded-lg bg-secondary p-3 text-left">
          <input
            type="checkbox"
            className="mt-1 size-4 accent-accent"
            checked={flushSnapshots}
            onChange={(e) => setFlushSnapshots(e.target.checked)}
          />
          <span>
            <span className="block text-sm font-medium">
              Flush {snapshotCount} APFS local snapshots
            </span>
            <span className="mt-0.5 block text-xs text-muted-foreground">
              {formatBytes(snapshotBytes)} via {SNAPSHOTS.command}
            </span>
          </span>
        </label>
      )}

      {phase === "done" && snapshotsFlushed && (
        <p className="text-xs text-ok">Local snapshots flushed.</p>
      )}

      {items.length > 0 && phase !== "idle" && (
        <ul className="w-full space-y-1.5 text-left">
          {items.slice(0, 4).map((item) => (
            <li
              key={item.id}
              className="flex items-center justify-between gap-3 text-xs text-muted-foreground"
            >
              <span className="truncate">{item.category}</span>
              <span className="font-mono tabular-nums text-foreground">
                {formatBytes(item.bytes)}
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function CategoryPane({ tier }: { tier: 1 | 2 }) {
  const items = usePruneStore((s) => s.items);
  const phase = usePruneStore((s) => s.phase);
  const toggleItem = usePruneStore((s) => s.toggleItem);
  const startScan = usePruneStore((s) => s.startScan);
  const filtered = useMemo(() => items.filter((i) => i.tier === tier), [items, tier]);

  if (phase === "idle") {
    return (
      <EmptyScan
        title={tier === 1 ? "Safe caches" : "Review required"}
        body={
          tier === 1
            ? "Tier 1 paths from SafetyRules.swift: Caches, Logs, DerivedData, npm, cargo, Gradle."
            : "Tier 2 paths: Containers, Application Support, Docker Desktop. Unchecked by default."
        }
        onScan={startScan}
      />
    );
  }

  if (filtered.length === 0) {
    return (
      <p className="text-sm text-muted-foreground">Still enumerating this tier…</p>
    );
  }

  return (
    <div className="space-y-3">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h2 className="text-lg font-medium tracking-tight">
            {tier === 1 ? "Caches" : "Review"}
          </h2>
          <p className="text-sm text-muted-foreground">
            {tier === 1
              ? "Pre-selected. Safe to send to Trash."
              : "Review before purge. Native app never auto-selects these."}
          </p>
        </div>
        <Badge variant={tier === 1 ? "ok" : "accent"}>Tier {tier}</Badge>
      </div>
      <ul className="space-y-2">
        {filtered.map((item) => (
          <CategoryRow key={item.id} item={item} onToggle={() => toggleItem(item.id)} />
        ))}
      </ul>
    </div>
  );
}

function CategoryRow({ item, onToggle }: { item: FoundItem; onToggle: () => void }) {
  const disabled = item.status === "purged";
  return (
    <li
      className={cn(
        "rounded-lg bg-secondary p-3",
        disabled && "opacity-50",
      )}
    >
      <label className="flex cursor-pointer items-start gap-3">
        <input
          type="checkbox"
          className="mt-1 size-4 accent-accent"
          checked={item.selected}
          disabled={disabled}
          onChange={onToggle}
        />
        <span className="min-w-0 flex-1">
          <span className="flex items-baseline justify-between gap-3">
            <span className="text-sm font-medium">{item.category}</span>
            <span className="font-mono text-sm tabular-nums">{formatBytes(item.bytes)}</span>
          </span>
          <span className="mt-0.5 block truncate font-mono text-[11px] text-faint">
            {item.path}
          </span>
          <span className="mt-1 block text-xs leading-relaxed text-muted-foreground">
            {item.note}
          </span>
        </span>
      </label>
    </li>
  );
}

function LicensePane() {
  const activated = usePruneStore((s) => s.activated);
  const licenseKey = usePruneStore((s) => s.licenseKey);
  const setShowLicense = usePruneStore((s) => s.setShowLicense);

  return (
    <div className="mx-auto max-w-md space-y-5">
      <div className="flex items-center gap-2">
        <HardDrive className="size-4 text-accent" />
        <h2 className="text-lg font-medium tracking-tight">License</h2>
      </div>
      {activated ? (
        <div className="rounded-lg bg-secondary p-4">
          <Badge variant="ok">Activated</Badge>
          <p className="mt-3 font-mono text-sm tracking-wide">{licenseKey}</p>
          <p className="mt-2 text-xs text-muted-foreground">
            On the native app this key is stored in the Keychain as DiskPruneLicense and
            verified against api.diskprune.com.
          </p>
        </div>
      ) : (
        <div className="space-y-4">
          <p className="text-sm leading-relaxed text-muted-foreground">
            Scanning is free. Purging requires a valid lifetime license ({PRODUCT.priceLabel}).
            Native activation POSTs to {PRODUCT.apiActivate}.
          </p>
          <Button onClick={() => setShowLicense(true)}>Enter license key</Button>
          <p>
            <a href={PRODUCT.stripeUrl} className="text-sm text-accent hover:underline">
              Buy DiskPrune lifetime — {PRODUCT.priceLabel}
            </a>
          </p>
        </div>
      )}
    </div>
  );
}

function EmptyScan({
  title,
  body,
  onScan,
}: {
  title: string;
  body: string;
  onScan: () => void;
}) {
  return (
    <div className="mx-auto max-w-md space-y-4 py-8 text-center">
      <h2 className="text-lg font-medium tracking-tight">{title}</h2>
      <p className="text-sm leading-relaxed text-muted-foreground">{body}</p>
      <Button onClick={onScan}>Start scan</Button>
    </div>
  );
}
