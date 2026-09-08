import { Link } from "@tanstack/react-router";
import { Wordmark } from "@/components/wordmark";
import { PRODUCT } from "@/lib/product";
import { GUIDES } from "@/lib/blog";

export function SiteFooter() {
  return (
    <footer className="border-t border-border mt-20">
      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-12 sm:px-6 md:grid-cols-3">
        <div className="space-y-3">
          <Wordmark />
          <p className="max-w-xs text-sm leading-relaxed text-muted-foreground">
            Native SwiftUI storage manager for macOS. Scan free. Lifetime license {PRODUCT.priceLabel}.
          </p>
        </div>
        <div>
          <p className="mb-3 text-xs font-medium uppercase tracking-widest text-faint">Product</p>
          <ul className="space-y-2 text-sm">
            <li>
              <Link to="/app" className="text-muted-foreground hover:text-foreground">
                App demo
              </Link>
            </li>
            <li>
              <a href={PRODUCT.dmgUrl} className="text-muted-foreground hover:text-foreground">
                Download .dmg
              </a>
            </li>
            <li>
              <a href={PRODUCT.stripeUrl} className="text-muted-foreground hover:text-foreground">
                Buy lifetime
              </a>
            </li>
            <li>
              <a href={PRODUCT.repoUrl} className="text-muted-foreground hover:text-foreground">
                Source on GitHub
              </a>
            </li>
          </ul>
        </div>
        <div>
          <p className="mb-3 text-xs font-medium uppercase tracking-widest text-faint">Guides</p>
          <ul className="space-y-2 text-sm">
            {GUIDES.map((g) => (
              <li key={g.slug}>
                <Link
                  to="/blog/$slug"
                  params={{ slug: g.slug }}
                  className="text-muted-foreground hover:text-foreground"
                >
                  {g.title}
                </Link>
              </li>
            ))}
          </ul>
        </div>
      </div>
      <div className="mx-auto flex max-w-6xl flex-col gap-2 px-4 pb-10 text-xs text-faint sm:flex-row sm:justify-between sm:px-6">
        <p>macOS 14+. Ad-hoc signed. Open Anyway in Privacy & Security on Sequoia.</p>
        <p>Scan is a simulated developer Mac in this preview. The .dmg runs on yours.</p>
      </div>
    </footer>
  );
}
