import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowRight, ScanSearch, ShieldCheck, TimerReset } from "lucide-react";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { MacApp } from "@/components/mac-app";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { COMPARISON, PRODUCT } from "@/lib/product";
import { GUIDES } from "@/lib/blog";

export const Route = createFileRoute("/")({ component: Home });

function Home() {
  return (
    <div className="min-h-dvh">
      <SiteHeader />
      <main>
        <Hero />
        <Safety />
        <Compare />
        <Pricing />
        <Guides />
      </main>
      <SiteFooter />
    </div>
  );
}

function Hero() {
  return (
    <section className="mx-auto max-w-6xl px-4 pb-4 pt-10 sm:px-6 sm:pt-14 lg:grid lg:grid-cols-2 lg:items-center lg:gap-10 lg:pb-12">
      <div className="max-w-xl">
        <Badge variant="outline">Native SwiftUI · {PRODUCT.os}</Badge>
        <h1 className="mt-5 text-4xl font-semibold tracking-tight sm:text-5xl sm:leading-tight lg:text-6xl">
          Reclaim gigabytes. Keep the files that matter.
        </h1>
        <p className="mt-5 text-base leading-relaxed text-muted-foreground sm:text-lg">
          DiskPrune scans developer caches, Xcode DerivedData, Docker’s disk image, and APFS
          local snapshots — then moves only what you approve to Trash. Scan is free. Lifetime
          license {PRODUCT.priceLabel}.
        </p>
        <div className="mt-7 flex flex-col gap-3 sm:flex-row">
          <Button asChild size="lg">
            <Link to="/app">
              Try the app demo
              <ArrowRight />
            </Link>
          </Button>
          <Button asChild size="lg" variant="secondary">
            <a href={PRODUCT.dmgUrl}>Free download</a>
          </Button>
        </div>
        <p className="mt-4 text-sm text-faint">
          Ad-hoc signed .dmg. On Sequoia: Privacy & Security → Open Anyway.
        </p>
      </div>
      <div className="mt-10 lg:mt-0">
        <div className="mb-3 flex items-center justify-between">
          <p className="text-xs uppercase tracking-widest text-faint">Live scan demo</p>
          <Link to="/app" className="text-xs text-accent hover:underline">
            Full window
          </Link>
        </div>
        <MacApp variant="hero" />
      </div>
    </section>
  );
}

function Safety() {
  const items = [
    {
      icon: ScanSearch,
      title: "Tier 1 · Safe caches",
      body: "~/Library/Caches, Logs, Xcode DerivedData, ~/.npm/_cacache, Cargo, Gradle. Pre-selected. Recreated by the tools that made them.",
    },
    {
      icon: ShieldCheck,
      title: "Tier 2 · Review",
      body: "Containers, Application Support, Docker Desktop. Unchecked until you say so. Purge uses trashItem — not rm -rf.",
    },
    {
      icon: TimerReset,
      title: "APFS snapshots",
      body: "After Trash, the native app runs tmutil deletelocalsnapshots /. That is how purgeable space actually becomes free.",
    },
  ];
  return (
    <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6">
      <h2 className="text-2xl font-semibold tracking-tight sm:text-3xl">A narrow safety engine</h2>
      <p className="mt-2 max-w-2xl text-muted-foreground">
        Ported from SafetyRules.swift and ScannerActor.swift. Full Disk Access is checked against
        the TCC database on a real Mac. This preview does not touch your disk.
      </p>
      <div className="mt-8 grid gap-4 md:grid-cols-3">
        {items.map((item) => {
          const Icon = item.icon;
          return (
            <article key={item.title} className="rounded-xl bg-card p-5 shadow-[var(--shadow-border)]">
              <Icon className="size-5 text-accent" />
              <h3 className="mt-4 text-base font-medium">{item.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{item.body}</p>
            </article>
          );
        })}
      </div>
    </section>
  );
}

function Compare() {
  return (
    <section className="mx-auto max-w-6xl px-4 py-10 sm:px-6">
      <h2 className="text-2xl font-semibold tracking-tight sm:text-3xl">Why DiskPrune</h2>
      <div className="mt-6 hidden overflow-hidden rounded-xl shadow-[var(--shadow-border)] md:block">
        <table className="w-full text-left text-sm">
          <thead className="bg-card text-muted-foreground">
            <tr>
              <th className="px-5 py-3 font-medium">Feature</th>
              <th className="px-5 py-3 font-medium text-accent">DiskPrune</th>
              <th className="px-5 py-3 font-medium">DissectMac</th>
              <th className="px-5 py-3 font-medium">Disk Buddy</th>
            </tr>
          </thead>
          <tbody>
            {COMPARISON.map((row) => (
              <tr key={row.feature} className="border-t border-border">
                <td className="px-5 py-3 text-muted-foreground">{row.feature}</td>
                <td className="px-5 py-3 text-foreground">{row.diskprune}</td>
                <td className="px-5 py-3 text-faint">{row.dissect}</td>
                <td className="px-5 py-3 text-faint">{row.buddy}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="mt-6 space-y-3 md:hidden">
        {COMPARISON.map((row) => (
          <article key={row.feature} className="rounded-xl bg-card p-4 shadow-[var(--shadow-border)]">
            <p className="text-xs uppercase tracking-widest text-faint">{row.feature}</p>
            <p className="mt-1 text-sm">
              <span className="text-accent">DiskPrune</span> · {row.diskprune}
            </p>
            <p className="mt-1 text-xs text-faint">DissectMac · {row.dissect}</p>
            <p className="text-xs text-faint">Disk Buddy · {row.buddy}</p>
          </article>
        ))}
      </div>
    </section>
  );
}

function Pricing() {
  return (
    <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6">
      <div className="rounded-2xl bg-card px-6 py-10 shadow-[var(--shadow-border)] sm:px-10">
        <p className="text-xs font-medium uppercase tracking-widest text-faint">Pricing</p>
        <div className="mt-3 flex flex-col gap-8 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p className="font-mono text-5xl font-medium tracking-tight">{PRODUCT.priceLabel}</p>
            <p className="mt-2 text-lg text-muted-foreground">One-time. No subscription.</p>
            <ul className="mt-6 space-y-2 text-sm text-muted-foreground">
              <li>Unlimited scans on every Mac you own</li>
              <li>Purge + APFS snapshot flush</li>
              <li>License in Keychain, verified at api.diskprune.com</li>
            </ul>
          </div>
          <div className="flex flex-col gap-3 sm:flex-row">
            <Button asChild size="lg">
              <a href={PRODUCT.stripeUrl}>Buy lifetime</a>
            </Button>
            <Button asChild size="lg" variant="secondary">
              <a href={PRODUCT.dmgUrl}>Download .dmg</a>
            </Button>
          </div>
        </div>
        <div className="mt-8 rounded-lg bg-secondary p-4 text-sm leading-relaxed text-muted-foreground">
          <p className="font-medium text-foreground">Opening on Sequoia and Sonoma</p>
          <ol className="mt-2 list-decimal space-y-1 pl-5">
            <li>Drag DiskPrune.app into /Applications.</li>
            <li>If macOS blocks an untrusted developer, open System Settings → Privacy & Security.</li>
            <li>Scroll to Security and click Open Anyway.</li>
          </ol>
        </div>
      </div>
    </section>
  );
}

function Guides() {
  return (
    <section className="mx-auto max-w-6xl px-4 pb-8 sm:px-6">
      <div className="mb-6 flex items-end justify-between">
        <h2 className="text-2xl font-semibold tracking-tight">Guides</h2>
        <Link to="/blog" className="text-sm text-accent hover:underline">
          All guides
        </Link>
      </div>
      <div className="grid gap-4 md:grid-cols-2">
        {GUIDES.map((g) => (
          <Link
            key={g.slug}
            to="/blog/$slug"
            params={{ slug: g.slug }}
            className="rounded-xl bg-card p-5 shadow-[var(--shadow-border)] transition-[box-shadow] duration-150 hover:shadow-[var(--shadow-border-hover)]"
          >
            <p className="text-xs text-faint">{g.minutes} min read</p>
            <h3 className="mt-2 text-base font-medium">{g.title}</h3>
            <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{g.desc}</p>
          </Link>
        ))}
      </div>
    </section>
  );
}
