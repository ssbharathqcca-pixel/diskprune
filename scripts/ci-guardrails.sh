#!/usr/bin/env bash
# CI job 3 — destructive-operation and architecture guardrails.
# These are a regression alarm on the safety architecture, not the safety mechanism.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/app/Sources/DiskPrune"
WORKER_SRC="$ROOT/worker/src"
FAIL=0

note() { printf '%s\n' "$*"; }
fail() { printf 'GUARDRAIL FAIL: %s\n' "$*" >&2; FAIL=1; }

if [[ ! -d "$SRC" ]]; then
  fail "missing $SRC"
  exit 1
fi

# Permanent deletion APIs
if grep -RInE 'removeItem(At)?[[:space:]]*\(' "$SRC" --include='*.swift' >/dev/null 2>&1; then
  grep -RInE 'removeItem(At)?[[:space:]]*\(' "$SRC" --include='*.swift' >&2 || true
  fail "FileManager.removeItem / removeItemAt is prohibited; cleanup must use trashItem only"
fi

# POSIX deletion
if grep -RInE '(^|[^[:alnum:]_])(unlink|rmdir)[[:space:]]*\(' "$SRC" --include='*.swift' >/dev/null 2>&1; then
  grep -RInE '(^|[^[:alnum:]_])(unlink|rmdir)[[:space:]]*\(' "$SRC" --include='*.swift' >&2 || true
  fail "POSIX unlink/rmdir is prohibited"
fi

# Shell deletion
if grep -RInE 'rm[[:space:]]+-r' "$SRC" --include='*.swift' >/dev/null 2>&1; then
  grep -RInE 'rm[[:space:]]+-r' "$SRC" --include='*.swift' >&2 || true
  fail "rm -r / rm -rf is prohibited"
fi

# Process / NSTask — only SnapshotInspector.swift may spawn a process
process_hits="$(grep -RInE '\b(Process|NSTask)[[:space:]]*\(' "$SRC" --include='*.swift' | grep -v 'SnapshotInspector.swift' || true)"
if [[ -n "$process_hits" ]]; then
  printf '%s\n' "$process_hits" >&2
  fail "Process/NSTask is only allowed in Scanning/SnapshotInspector.swift"
fi

# tmutil / snapshot deletion — SnapshotInspector may contain listlocalsnapshots only
tmutil_hits="$(grep -RInE 'tmutil|deletelocalsnapshots' "$SRC" --include='*.swift' | grep -v 'SnapshotInspector.swift' || true)"
if [[ -n "$tmutil_hits" ]]; then
  printf '%s\n' "$tmutil_hits" >&2
  fail "tmutil is only allowed in SnapshotInspector.swift (listlocalsnapshots)"
fi

if [[ -f "$SRC/Scanning/SnapshotInspector.swift" ]]; then
  if grep -n 'deletelocalsnapshots' "$SRC/Scanning/SnapshotInspector.swift" >/dev/null 2>&1; then
    grep -n 'deletelocalsnapshots' "$SRC/Scanning/SnapshotInspector.swift" >&2 || true
    fail "SnapshotInspector must not contain deletelocalsnapshots"
  fi
fi

# Whole-repo snapshot deletion (source). Exclude docs that explain the prohibition
# and this script itself.
snap_hits="$(grep -RIn 'deletelocalsnapshots' "$ROOT" \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=dist \
  --exclude-dir=.build \
  --exclude-dir=.swiftpm \
  --exclude-dir=web \
  --exclude-dir=site \
  --exclude='*.md' \
  --exclude='ci-guardrails.sh' || true)"
if [[ -n "$snap_hits" ]]; then
  printf '%s\n' "$snap_hits" >&2
  fail "deletelocalsnapshots must not appear in production source (T-SNAP-03)"
fi

# Module-boundary greps (single SPM module: still forbid the words)
if grep -RIn 'import[[:space:]]\+Cleanup' "$SRC/Scanning" --include='*.swift' >/dev/null 2>&1; then
  fail "Scanning/ must not import Cleanup"
fi
if grep -RIn 'import[[:space:]]\+Scanning' "$SRC/Cleanup" --include='*.swift' >/dev/null 2>&1; then
  fail "Cleanup/ must not import Scanning"
fi
if [[ -d "$SRC/Scanning" && -d "$SRC/Cleanup" ]]; then
  if grep -RIn 'CleanupExecutor' "$SRC/Scanning" --include='*.swift' >/dev/null 2>&1; then
    grep -RIn 'CleanupExecutor' "$SRC/Scanning" --include='*.swift' >&2 || true
    fail "Scanning/ must not reference CleanupExecutor"
  fi
  if grep -RIn 'ScanEngine' "$SRC/Cleanup" --include='*.swift' >/dev/null 2>&1; then
    grep -RIn 'ScanEngine' "$SRC/Cleanup" --include='*.swift' >&2 || true
    fail "Cleanup/ must not reference ScanEngine"
  fi
fi

# Insecure randomness in the worker
if [[ -d "$WORKER_SRC" ]]; then
  if grep -RIn 'Math\.random' "$WORKER_SRC" >/dev/null 2>&1; then
    grep -RIn 'Math\.random' "$WORKER_SRC" >&2 || true
    fail "Math.random is prohibited in worker/src (use crypto.getRandomValues)"
  fi
fi

# Terminology contract (Correction 1) — only once those views exist
for f in "$SRC/UI/ReceiptView.swift" "$SRC/UI/CleanupPlanView.swift"; do
  if [[ -f "$f" ]]; then
    if grep -nEiw 'freed|reclaimed' "$f" >/dev/null 2>&1; then
      grep -nEiw 'freed|reclaimed' "$f" >&2 || true
      fail "T-TERM-01: 'freed'/'reclaimed' are forbidden in $(basename "$f")"
    fi
  fi
done

if [[ "$FAIL" -ne 0 ]]; then
  note "Guardrails failed."
  exit 1
fi
note "Guardrails passed."
