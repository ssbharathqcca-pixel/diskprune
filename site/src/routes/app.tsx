import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowLeft } from "lucide-react";
import { MacApp } from "@/components/mac-app";
import { Wordmark } from "@/components/wordmark";
import { PRODUCT } from "@/lib/product";

export const Route = createFileRoute("/app")({
  component: AppDemo,
  head: () => ({
    meta: [{ title: "DiskPrune — App demo" }],
  }),
});

function AppDemo() {
  return (
    <div className="flex min-h-dvh flex-col">
      <header className="flex h-14 items-center justify-between border-b border-border px-4 sm:px-6">
        <Link to="/" className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground">
          <ArrowLeft className="size-4" />
          <Wordmark />
        </Link>
        <p className="hidden text-xs text-faint sm:block">
          Interactive preview · native app is the .dmg
        </p>
        <a href={PRODUCT.dmgUrl} className="text-sm text-accent hover:underline">
          Download
        </a>
      </header>
      <div className="mx-auto flex w-full max-w-6xl flex-1 flex-col px-4 py-4 sm:px-6 sm:py-6">
        <MacApp variant="full" />
      </div>
    </div>
  );
}
