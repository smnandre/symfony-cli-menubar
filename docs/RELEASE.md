# Release Process

## TL;DR

```bash
git tag v1.0.1 && git push origin v1.0.1
```

That's it. CI handles everything else automatically.

---

## What CI does on tag push

| Step | What happens |
|------|-------------|
| Validate secrets | Fails fast if any required secret is missing |
| Run tests | `swift test` |
| Build | Universal binary (arm64 + x86_64) via `swift build` |
| Sign | Developer ID Application certificate, hardened runtime, entitlements |
| Embed Sparkle | Copies framework, signs all XPC services inside-out |
| Create DMG | `scripts/create-dmg.sh` — signed and notarized |
| Notarize | Submits to Apple, waits for `Accepted`, staples ticket to DMG and `.app` |
| Create ZIP | For Sparkle in-app updates, signed with EdDSA (`sign_update`) |
| Update `CHANGELOG.md` | Promotes `[Unreleased]` → `[1.0.1] - YYYY-MM-DD` (if not already done) |
| Update `config/version.env` | Syncs `MARKETING_VERSION` to the tag version |
| Update `docs/web/index.html` | Version badge and download URL |
| Update `docs/appcast.xml` | Prepends new Sparkle feed entry with EdDSA signature |
| Commit back to `main` | Single commit: `chore: release v1.0.1` |
| Create GitHub Release | Uploads DMG, ZIP, and SHA256 checksums |

---

## Recommended: write release notes before tagging

CI auto-creates the `[1.0.1]` section in `CHANGELOG.md`, but cannot write the release notes for you. Add them before tagging:

```bash
# edit CHANGELOG.md — add notes under [Unreleased]
git add CHANGELOG.md
git commit -m "chore: release notes for v1.0.1"
git push
```

Then tag:

```bash
git tag v1.0.1 && git push origin v1.0.1
```

### Optional: preview all file changes locally first

```bash
bash scripts/bump-version.sh 1.0.1
```

Updates `config/version.env`, `CHANGELOG.md`, and `docs/web/index.html` locally so you can review the diff before pushing the tag. CI will skip any file already up to date.

---

## Pre-releases

Use a tag suffix: `v1.0.0-beta.1` or `v1.0.0-rc.1`.

The workflow auto-detects the suffix and marks the GitHub Release as **Pre-release**. Sparkle will not offer pre-release versions to users on the stable channel.

---

## Required secrets

Configure these in **GitHub → Settings → Secrets → Actions**:

| Secret | Purpose |
|--------|---------|
| `APPLE_DEVELOPER_ID_P12` | Base64-encoded Developer ID Application certificate (`.p12`) |
| `APPLE_DEVELOPER_ID_PASSWORD` | Password for the `.p12` file |
| `APPLE_ID` | Apple ID used for notarization |
| `APPLE_NOTARIZATION_PASSWORD` | App-specific password for notarization |
| `APPLE_TEAM_ID` | 10-character Apple Developer Team ID |
| `SPARKLE_PRIVATE_KEY` | EdDSA private key for signing ZIP updates |
| `SPARKLE_PUBLIC_KEY` | EdDSA public key embedded in `Info.plist` as `SUPublicEDKey` |

See `.github/SIGNING.md` for how to generate and configure these.

