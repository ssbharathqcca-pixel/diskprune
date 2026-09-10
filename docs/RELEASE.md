# Gate 5 — macOS release engineering

Fail closed. An ad-hoc signed DMG is **not** a release. Gate 5 is **not PASS**
until PART 19.4 checks 1–9 pass against the `.app` **inside the mounted DMG**
and checks 10–12 pass on real Macs.

This sandbox cannot compile Swift, codesign, or notarize. GitHub Actions
`macos-14` can, **if** the secrets below exist.

## What the pipeline does

| Script | Role |
| --- | --- |
| [`scripts/build-universal.sh`](../scripts/build-universal.sh) | `swift build --arch arm64` + `--arch x86_64`, `lipo`, assemble `DiskPrune.app`. **No** `-DDISKPRUNE_VISUAL_QA`. **No** signing. Resource bundles must be byte-identical. |
| [`scripts/import-developer-id.sh`](../scripts/import-developer-id.sh) | Ephemeral keychain. Import `DEVELOPER_ID_CERT_P12`. Identity must contain `Developer ID Application` and `APPLE_TEAM_ID`. |
| [`scripts/release-macos.sh`](../scripts/release-macos.sh) | Universal → nested `codesign --options runtime --timestamp` (not `--deep`) → notarize app zip → staple app → UDZO DMG → sign DMG → notarize DMG → staple DMG → SHA-256 → `verify-release.sh`. |
| [`scripts/verify-release.sh`](../scripts/verify-release.sh) | Checks 1–9 automated against the mounted DMG. Checks 10–12 printed as MANUAL. |
| [`scripts/package-macos.sh`](../scripts/package-macos.sh) | **Visual QA only.** Single-arch, ad-hoc, compiles the Visual QA catalog. Never published as a GitHub Release. |

Entitlements: [`app/Packaging/DiskPrune.entitlements`](../app/Packaging/DiskPrune.entitlements) — empty. Hardened runtime, no App Sandbox, no `get-task-allow`.

## GitHub Actions secrets (required)

Create these on `ssbharathqcca-pixel/diskprune` → Settings → Secrets and variables → Actions.
Missing secrets **fail the tag job**. They do not produce an ad-hoc stand-in.

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_CERT_P12` | Base64 of a PKCS#12 containing **Developer ID Application** (not Mac App Store, not Apple Development). |
| `DEVELOPER_ID_CERT_PASSWORD` | Password for that `.p12`. |
| `APPLE_TEAM_ID` | 10-character Team ID, e.g. the `(ABCDE12345)` suffix on the identity. |
| `ASC_KEY_ID` | App Store Connect API key id (Issuer keys at [App Store Connect → Users and Access → Integrations](https://appstoreconnect.apple.com/access/integrations/api)). |
| `ASC_ISSUER_ID` | App Store Connect issuer UUID. |
| `ASC_KEY_P8` | Full PEM contents of the `.p8` (`-----BEGIN PRIVATE KEY-----` …). Role must be allowed to notarize. |
| `DEVELOPER_ID_IDENTITY` | Optional exact identity string `Developer ID Application: Name (TEAMID)`. |

Also required outside GitHub:

1. **Apple Developer Program** membership ($99/yr) on the team that issued the Developer ID certificate.
2. A **Developer ID Application** certificate (and private key) exported as `.p12`.
3. The certificate’s Apple Worldwide Developer Relations intermediate installed on the signing Mac / runner (the p12 usually carries it).
4. Notary access via the App Store Connect API key (not an app-specific password; this pipeline uses `notarytool --key/--key-id/--issuer`).

### Export the p12 (on a Mac that already has the identity)

```bash
security find-identity -v -p codesigning
# note the "Developer ID Application: … (TEAMID)" line

security export \
  -k login.keychain-db \
  -t identities \
  -f pkcs12 \
  -o developer-id.p12
base64 -i developer-id.p12 | pbcopy   # paste into DEVELOPER_ID_CERT_P12
```

Do not commit the p12, the p8, or the base64.

## Local commands (macOS only)

```bash
bash scripts/release-macos.sh --prereqs
# after secrets are exported in the environment, on a tagged commit:
git checkout v1.0.0
bash scripts/release-macos.sh
shasum -c dist/release/DiskPrune.dmg.sha256
```

`--universal-only` builds the fat app without signing (CI job “Universal binary”).

## Version

| Field | Source |
| --- | --- |
| `CFBundleShortVersionString` | git tag with leading `v` stripped (`v1.0.0` → `1.0.0`) |
| `CFBundleVersion` | `1.0.0.<github.run_number>` |
| Untagged | `0.0.0-dev` — `release-macos.sh` refuses unless `DISKPRUNE_ALLOW_UNTAGGED=1` |

## Visual QA vs release

Release binaries are compiled **without** `-DDISKPRUNE_VISUAL_QA`. `VisualQACatalog` / `VisualQAHost` are absent. `scripts/package-macos.sh` still passes the define so Visual QA CI works. `Info.plist` must not contain `LSEnvironment.DISKPRUNE_VISUAL_QA`.

## 12-point checks (PART 19.4)

Automated in `verify-release.sh` against the **mounted** DMG:

1. `codesign -dv --verbose=4` → Developer ID Application
2. `codesign --verify --deep --strict`
3. Hardened runtime (`flags` includes `runtime`)
4. `Timestamp=`
5. `notarytool log` Accepted (when the log is present)
6. `stapler validate` on DMG **and** app
7. `spctl -a -vvv -t install` → accepted, Notarized Developer ID
8. `hdiutil verify`
9. `lipo -archs` on the executable **inside the mounted DMG** → `x86_64 arm64`

Manual — **these gate the release; CI cannot pass them**:

10. Extracted app launches
11. Clean Mac: Safari download → SHA-256 → double-click → drag → launch, no Terminal, no System Settings
12. Intel Mac launches

## What this does not do

- It does not declare Gate 5 PASS.
- It does not publish a live (non-draft) GitHub Release. Tag releases are **draft + prerelease** until 10–12 pass.
- It does not invent a Developer ID or skip notarization.
- It does not change cleanup, licensing, or UI.

## After secrets exist

1. Push this branch / merge to `main`.
2. Confirm the **Universal binary** job is green (`lipo -archs` is `x86_64 arm64`).
3. Add the seven secrets.
4. Tag `v1.0.0` (or the real version) on the commit you intend to ship.
5. The **Developer ID + notarize + staple** job must go green. If secrets are missing it **fails**.
6. Download the artifact `DiskPrune-notarized-v1.0.0`. Run checks 10–12 yourself.
7. Only then undraft the GitHub Release. Only then may marketing say “notarized”.
