import { formatBytes } from "@/lib/utils";

type DiskRingProps = {
  value: number;
  capacity?: number;
  label: string;
};

export function DiskRing({ value, capacity = 82_522_000_000, label }: DiskRingProps) {
  const radius = 54;
  const c = 2 * Math.PI * radius;
  const ratio = Math.min(1, value / capacity);
  const dash = `${(ratio * c).toFixed(2)} ${c.toFixed(2)}`;

  return (
    <div className="relative mx-auto size-32 sm:size-40">
      <svg viewBox="0 0 128 128" className="size-full -rotate-90" aria-hidden="true">
        <circle
          cx="64"
          cy="64"
          r={radius}
          fill="none"
          stroke="currentColor"
          className="text-secondary"
          strokeWidth="8"
        />
        <circle
          cx="64"
          cy="64"
          r={radius}
          fill="none"
          stroke="currentColor"
          className="text-accent"
          strokeWidth="8"
          strokeLinecap="round"
          strokeDasharray={dash}
          style={{
            transition: "stroke-dasharray 400ms var(--ease-smooth-out)",
          }}
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
        <span className="font-mono text-xl font-medium tabular-nums tracking-tight">
          {formatBytes(value)}
        </span>
        <span className="mt-0.5 text-[11px] uppercase tracking-widest text-faint">{label}</span>
      </div>
    </div>
  );
}
