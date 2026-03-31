# Changelog

All notable changes to Symfony CLI Menu Bar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.10.3] - 2026-03-31

### Added
- `scripts/bump-version.sh` — optional local tool to preview version bump before tagging
- `.github/README.md` — index of workflows, scripts, and config files

### Changed
- Release pipeline fully automated on tag push: syncs `version.env`, `CHANGELOG.md`, `docs/web/index.html`, `appcast.xml` and commits back to `main`
- `scripts/package.sh` now uses `VERSION` env var from the git tag, fixing version shown in About screen
- Docblocks added to all scripts documenting purpose, callers, and arguments

### Removed
- `scripts/notarize.sh` — dead code, notarization is handled inline in `release.yml`

## [0.9.6] - 2026-03-29
### Fixed
- Sign all Sparkle nested executables (Updater.app, Autoupdate, framework XPC services) for notarization
- Add apple-events entitlement for Terminal automation
- Replace fragile notarization diagnostics with reliable JSON-based submission ID capture
- Remove continue-on-error on notarization step so failures are reported immediately

## [0.9.5] - 2026-03-29
### Fixed
- Fix workflow syntax error in release automation

## [0.9.4] - 2026-03-29
### Fixed
- Restore notarization diagnostics step in CI

## [0.9.3] - 2026-03-29
### Fixed
- Robust recursive signing for notarization
- Added Apple Events entitlement for Terminal access
- Added automatic notarization log retrieval on failure

## [0.9.2] - 2026-03-29
### Fixed
- Fix notarization failure by improving entitlements and signing process

## [0.9.1] - 2026-03-29
### Fixed
- Fix DMG mount point handling for paths with spaces

## [0.9.0] - 2026-03-29

### Added
- Native macOS menu bar app for managing Symfony local servers.
- Server Management: Start, stop, and monitor status of Symfony servers.
- PHP Version Switching: List installed PHP versions and set the system default.
- Proxy Overview: Quick access to `.wip` local domains.
- Quick Actions: Open in browser, copy URL, view logs, and open in Terminal.
- Start at Login functionality.
