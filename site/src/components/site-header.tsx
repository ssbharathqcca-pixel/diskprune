import { Link } from "@tanstack/react-router";
import { Wordmark } from "@/components/wordmark";
import { Button } from "@/components/ui/button";
import { PRODUCT } from "@/lib/product";

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-40 border-b border-border/70 bg-background/85 backdrop-blur-md">
      <div className="mx-auto flex h-14 max-w-6xl items-center justify-between px-4 sm:px-6">
        <Link to="/" className="rounded-md focus-visible:ring-2 focus-visible:ring-ring">
          <Wordmark />
        </Link>
        <nav className="flex items-center gap-1 sm:gap-2">
          <Link
            to="/app"
            className="inline-flex h-11 items-center px-3 text-sm text-muted-foreground transition-colors duration-150 hover:text-foreground"
          >
            Demo
          </Link>
          <Link
            to="/blog"
            className="hidden h-11 items-center px-3 text-sm text-muted-foreground transition-colors duration-150 hover:text-foreground sm:inline-flex"
          >
            Guides
          </Link>
          <Button asChild size="sm" variant="secondary" className="hidden sm:inline-flex">
            <a href={PRODUCT.dmgUrl}>Download</a>
          </Button>
          <Button asChild size="sm">
            <a href={PRODUCT.stripeUrl}>Buy {PRODUCT.priceLabel}</a>
          </Button>
        </nav>
      </div>
    </header>
  );
}
