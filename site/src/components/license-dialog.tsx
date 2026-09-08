import { useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { PRODUCT } from "@/lib/product";
import { usePruneStore } from "@/lib/prune-store";

export function LicenseDialog() {
  const showLicense = usePruneStore((s) => s.showLicense);
  const setShowLicense = usePruneStore((s) => s.setShowLicense);
  const activate = usePruneStore((s) => s.activate);
  const licenseError = usePruneStore((s) => s.licenseError);
  const [draft, setDraft] = useState("");

  return (
    <Dialog open={showLicense} onOpenChange={setShowLicense}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>License required</DialogTitle>
          <DialogDescription>
            Scanning is free. Purging on the native Mac app requires a lifetime license. This
            preview accepts the demo key or a key issued after a simulated purchase.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-2">
          <Input
            autoFocus
            spellCheck={false}
            placeholder="PRUNE-XXXX-XXXX-XXXX"
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") activate(draft);
            }}
            aria-invalid={Boolean(licenseError)}
            className="font-mono uppercase"
          />
          {licenseError ? (
            <p className="text-xs text-destructive">{licenseError}</p>
          ) : (
            <p className="text-xs text-faint">
              Demo key: <span className="font-mono text-muted-foreground">{PRODUCT.demoKey}</span>
            </p>
          )}
        </div>
        <DialogFooter>
          <Button variant="ghost" onClick={() => setShowLicense(false)}>
            Cancel
          </Button>
          <Button onClick={() => activate(draft)}>Activate</Button>
        </DialogFooter>
        <a
          href={PRODUCT.stripeUrl}
          className="text-center text-sm text-accent hover:underline"
        >
          Buy license ({PRODUCT.priceLabel})
        </a>
      </DialogContent>
    </Dialog>
  );
}
