.PHONY: test lint package verify release-app release-dmg release-cask

VERSION := $(shell /usr/libexec/PlistBuddy -c 'Print :Version' config/Version.plist)

test:
	swift test

lint:
	swift-format lint --recursive Sources Tests Package.swift
	shellcheck scripts/*.sh assets/*.sh
	bash -n scripts/*.sh assets/*.sh
	yamllint .github/workflows .yamllint.yml
	plutil -lint config/entitlements.plist config/Version.plist
	git diff --check

package:
	VERSION="$(VERSION)" SIGNING_MODE=adhoc ARCHES=arm64 ./scripts/package.sh release
	codesign --verify --deep --strict --verbose=2 SymfonyCLIMenuBar.app

verify: test lint package

release-app:
	VERSION="$(VERSION)" SIGNING_MODE=developer APP_IDENTITY="$(APP_IDENTITY)" ARCHES=arm64 ./scripts/package.sh release

release-dmg:
	./scripts/create-dmg.sh "$(VERSION)"

release-cask:
	./scripts/render_homebrew_cask.sh "$(VERSION)" "$(SHA256)" "$(OUTPUT)"
