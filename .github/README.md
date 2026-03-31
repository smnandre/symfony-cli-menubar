# .github

This directory contains GitHub-specific configuration, CI workflows, and contributor documentation.

## Workflows

| File | Trigger | Purpose |
|------|---------|---------|
| `workflows/build.yml` | Push to `main`, `develop` | Build and test on every commit — fast feedback loop for PRs |
| `workflows/release.yml` | Push of `v*` tag | Full release pipeline: build, sign, notarize, package, publish |
| `workflows/deploy-docs.yml` | Push to `main` | Deploy `docs/web/` to GitHub Pages |

## Scripts

| File | Called by | Purpose |
|------|-----------|---------|
| `scripts/package.sh` | CI + local | Compile Swift, assemble `.app` bundle, sign with Developer ID |
| `scripts/embed_sparkle.sh` | `package.sh` | Copy Sparkle framework + XPC services into `.app`, sign inside-out |
| `scripts/create-dmg.sh` | CI + local | Package `.app` into a distributable DMG with Finder window layout |
| `scripts/update_appcast.sh` | CI | Prepend new Sparkle feed entry into `docs/appcast.xml` |
| `scripts/bump-version.sh` | Local only | Optional: preview version bump across all files before tagging |
| `assets/generate_icns.sh` | CI + local | Generate `AppIcon.icns` from the SVG source via `librsvg` |

## Files

| File | Purpose |
|------|---------|
| `CONTRIBUTING.md` | Contributor guide: setup, workflow, code style |
| `SIGNING.md` | How to generate and configure signing certificates and Sparkle keys |
| `SECURITY.md` | Security policy and vulnerability reporting |
| `FUNDING.yml` | GitHub Sponsors configuration |
| `copilot-instructions.md` | Copilot context: architecture, conventions, build commands |
| `pull_request_template.md` | Default PR description template |
| `ISSUE_TEMPLATE/` | Bug report and feature request templates |
