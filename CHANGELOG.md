# Changelog

## Unreleased

### Safety

- Removed APFS snapshot deletion (`tmutil deletelocalsnapshots`) from the native app. Snapshots are inspect-only in v1.
- Replaced `Math.random()` license-key generation in the Worker with `crypto.getRandomValues`. The Worker is still the pre-rewrite KV implementation; signature verification and D1 land in Phase 4.

### Repository

- Added CI jobs: Swift debug build, Swift tests, destructive-operation guardrails.
- Added a Swift test target.
- Stopped tracking `web/dist/`, `web/node_modules/`, and `worker/.wrangler/cache/wrangler-account.json`.
- Deleted `build-and-verify.sh` (superseded by CI).
- Added `/docs` status, decision, and limitations records.
