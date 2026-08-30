# .github

This directory contains GitHub-specific configuration, CI workflows, and contributor documentation.

## Workflows

| File | Trigger | Purpose |
|------|---------|---------|
| `workflows/build.yml` | Push to `main`, `develop` | Build and test on every commit - fast feedback loop for PRs |
| `workflows/release-preflight.yml` | Manual on `main` | Validate release credentials and signed packaging without publishing |
| `workflows/release.yml` | Push of `v*` tag | Full release pipeline: build, sign, notarize, package, publish |
| `workflows/deploy-docs.yml` | Push to `main` | Deploy `docs/web/` to GitHub Pages |

## Scripts

| File | Called by | Purpose |
|------|-----------|---------|
| `scripts/package.sh` | CI + local | Validate `VERSION`, compile Swift, assemble and sign the `.app` bundle |
| `scripts/create-dmg.sh` | CI + local | Package `.app` into a distributable DMG with Finder window layout |
| `scripts/render_homebrew_cask.sh` | CI + local | Render the cask with the released version and DMG checksum |
| `scripts/finalize-release-site.sh` | Local only | Update the public site after the release and cask are available |
| `scripts/bump-version.sh` | Local only | Optional: prepare the changelog section before tagging |
| `assets/generate_icns.sh` | CI + local | Generate `AppIcon.icns` from the SVG source via `librsvg` |

## Files

| File | Purpose |
|------|---------|
| `CONTRIBUTING.md` | Contributor guide: setup, workflow, code style |
| `SECURITY.md` | Security policy and vulnerability reporting |
| `FUNDING.yml` | GitHub Sponsors configuration |
| `copilot-instructions.md` | Copilot context: architecture, conventions, build commands |
| `pull_request_template.md` | Default PR description template |
| `ISSUE_TEMPLATE/` | Bug report and feature request templates |
