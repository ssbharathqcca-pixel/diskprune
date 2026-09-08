import { createFileRoute, Link } from "@tanstack/react-router";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { GUIDES } from "@/lib/blog";

export const Route = createFileRoute("/blog/")({
  component: BlogIndex,
  head: () => ({
    meta: [{ title: "Guides — DiskPrune" }],
  }),
});

function BlogIndex() {
  return (
    <div className="min-h-dvh">
      <SiteHeader />
      <main className="mx-auto max-w-3xl px-4 py-16 sm:px-6">
        <p className="text-xs font-medium uppercase tracking-widest text-faint">Guides</p>
        <h1 className="mt-2 text-4xl font-semibold tracking-tight">Clear space without guessing</h1>
        <p className="mt-3 text-muted-foreground">
          Manual walkthroughs for the same paths DiskPrune’s safety engine scans.
        </p>
        <ul className="mt-10 space-y-4">
          {GUIDES.map((g) => (
            <li key={g.slug}>
              <Link
                to="/blog/$slug"
                params={{ slug: g.slug }}
                className="block rounded-xl bg-card p-5 shadow-[var(--shadow-border)] transition-[box-shadow] duration-150 hover:shadow-[var(--shadow-border-hover)]"
              >
                <p className="text-xs text-faint">{g.minutes} min read</p>
                <h2 className="mt-1 text-lg font-medium">{g.title}</h2>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{g.desc}</p>
              </Link>
            </li>
          ))}
        </ul>
      </main>
      <SiteFooter />
    </div>
  );
}
