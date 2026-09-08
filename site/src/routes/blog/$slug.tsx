import { createFileRoute, Link, notFound } from "@tanstack/react-router";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { Button } from "@/components/ui/button";
import { getGuide, GUIDES } from "@/lib/blog";
import { PRODUCT } from "@/lib/product";

export const Route = createFileRoute("/blog/$slug")({
  loader: ({ params }) => {
    const guide = getGuide(params.slug);
    if (!guide) throw notFound();
    return { guide };
  },
  component: GuidePage,
  head: ({ loaderData }) => ({
    meta: [
      { title: `${loaderData?.guide.title ?? "Guide"} — DiskPrune` },
      { name: "description", content: loaderData?.guide.desc ?? "" },
    ],
  }),
});

function GuidePage() {
  const { guide } = Route.useLoaderData();
  const others = GUIDES.filter((g) => g.slug !== guide.slug);

  return (
    <div className="min-h-dvh">
      <SiteHeader />
      <main className="mx-auto max-w-2xl px-4 py-14 sm:px-6">
        <Link to="/" className="text-sm text-accent hover:underline">
          ← DiskPrune
        </Link>
        <p className="mt-8 text-xs text-faint">{guide.minutes} min read</p>
        <h1 className="mt-2 text-4xl font-semibold tracking-tight">{guide.title}</h1>
        <p className="mt-4 text-lg leading-relaxed text-muted-foreground">{guide.desc}</p>
        <div className="mt-6 rounded-lg bg-card p-4 text-sm leading-relaxed text-muted-foreground shadow-[var(--shadow-border)]">
          DiskPrune automates this with its tier-based safety engine and APFS snapshot flush.
          Scan free, {PRODUCT.priceLabel} lifetime to purge.
        </div>
        {guide.body.map((section) => (
          <section key={section.heading} className="mt-10">
            <h2 className="text-xl font-medium tracking-tight">{section.heading}</h2>
            {section.paragraphs.map((p) => (
              <p key={p.slice(0, 40)} className="mt-3 text-[15px] leading-relaxed text-muted-foreground">
                {p}
              </p>
            ))}
          </section>
        ))}
        <div className="mt-12 flex flex-col gap-3 sm:flex-row">
          <Button asChild>
            <a href={PRODUCT.stripeUrl}>Buy lifetime {PRODUCT.priceLabel}</a>
          </Button>
          <Button asChild variant="secondary">
            <Link to="/app">Try the demo</Link>
          </Button>
        </div>
        <div className="mt-16 border-t border-border pt-8">
          <p className="text-xs uppercase tracking-widest text-faint">More guides</p>
          <ul className="mt-3 space-y-2">
            {others.map((g) => (
              <li key={g.slug}>
                <Link
                  to="/blog/$slug"
                  params={{ slug: g.slug }}
                  className="text-sm text-accent hover:underline"
                >
                  {g.title}
                </Link>
              </li>
            ))}
          </ul>
        </div>
      </main>
      <SiteFooter />
    </div>
  );
}
