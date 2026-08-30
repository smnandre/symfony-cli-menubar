# Testing Guide

## Requirements

- Apple Silicon Mac with macOS 14 or later
- Full Xcode installation
- Symfony CLI for manual integration checks

## Automated tests

Run the Swift Testing suites:

```bash
swift test
```

The suites cover Symfony CLI parsing, server state transitions, path escaping, domain validation, known-server merging, semantic app versions, and update-check results.

Run a focused test by name:

```bash
swift test --filter UpdateCheckerTests
```

## Static checks

Before a release, run:

```bash
swift-format lint --recursive Sources Tests Package.swift
shellcheck scripts/*.sh assets/*.sh
bash -n scripts/*.sh assets/*.sh
yamllint .github/workflows .yamllint.yml
plutil -lint config/entitlements.plist
git diff --check
```

## Package verification

Build the same architecture published by the release workflow:

```bash
VERSION=1.0.0 ARCHES=arm64 SIGNING_MODE=adhoc ./scripts/package.sh release
file SymfonyCLIMenuBar.app/Contents/MacOS/SymfonyCLIMenuBar
test "$(plutil -extract CFBundleShortVersionString raw -o - SymfonyCLIMenuBar.app/Contents/Info.plist)" = "1.0.0"
test "$(plutil -extract CFBundleVersion raw -o - SymfonyCLIMenuBar.app/Contents/Info.plist)" = "1.0.0"
codesign --verify --deep --strict --verbose=2 SymfonyCLIMenuBar.app
```

This command deliberately uses an ad hoc signature for contributors. Maintainers should omit `SIGNING_MODE=adhoc` to verify the local Developer ID path. Only the tagged CI release proves notarization.

## Local update scenarios

Debug builds can replace the public cask with a local fixture. The override is not compiled into release builds.

```bash
VERSION=1.0.0 ARCHES=arm64 ./scripts/package.sh debug

SYMFONY_CLI_MENUBAR_CASK_FIXTURE="$PWD/Tests/Fixtures/UpdateCasks/newer.rb" \
SYMFONY_CLI_MENUBAR_CHECK_UPDATES_ON_LAUNCH=1 \
./SymfonyCLIMenuBar.app/Contents/MacOS/SymfonyCLIMenuBar
```

Repeat with `older.rb`, `current.rb`, and `invalid.rb`. The expected results are respectively no update, no update, version 1.1.0 available, and an invalid-cask error.

## Manual checklist

### Server management

- [ ] Detect running and stopped servers
- [ ] Start and stop a server
- [ ] Refresh the server list
- [ ] Handle a failed Symfony CLI command

### PHP and proxies

- [ ] Detect installed PHP versions and the default version
- [ ] Change the default PHP version
- [ ] List and open `.wip` proxy domains
- [ ] Copy paths and URLs

### macOS integration

- [ ] Open a server in the default browser
- [ ] Open logs and project directories in Terminal
- [ ] Toggle Start at Login, log out, and confirm the app starts in the next session
- [ ] Show the About window
- [ ] Check for updates against the version merged in `smnandre/homebrew-tap`
- [ ] Confirm the copied Homebrew command is correct

### Homebrew release

- [ ] Cask CI passes `brew style`, `brew audit`, ARM installation, signature checks, and uninstall
- [ ] The downloaded DMG checksum matches the cask
- [ ] Gatekeeper accepts the installed app as a notarized Developer ID build
- [ ] `brew upgrade --cask symfony-cli-menubar` resolves after the initial trusted install

## CI boundaries

- `build.yml` runs the Swift build and tests on commits and pull requests.
- `release.yml` performs the signed ARM-only package, notarization, GitHub Release, and cask PR creation.
- The tap repository validates the rendered cask independently before it is merged.
