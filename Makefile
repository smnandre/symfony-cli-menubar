.PHONY: help build test lint package run verify clean release-app release-dmg release-cask
.DEFAULT_GOAL := help

APP := SymfonyCLIMenuBar
VERSION := $(shell /usr/libexec/PlistBuddy -c 'Print :Version' config/Version.plist)
BUILD := $(shell /usr/libexec/PlistBuddy -c 'Print :Build' config/Version.plist)

help:
	@printf '%s\n' 'make build        Compile the app'
	@printf '%s\n' 'make test         Run tests'
	@printf '%s\n' 'make lint         Run static checks'
	@printf '%s\n' 'make package      Build the arm64 app bundle'
	@printf '%s\n' 'make run          Build and launch the app'
	@printf '%s\n' 'make verify       Run every local validation'

build:
	swift build --arch arm64

test:
	swift test

lint:
	swift-format lint --recursive --strict Sources Tests Package.swift
	shellcheck scripts/*.sh assets/*.sh
	bash -n scripts/*.sh assets/*.sh
	yamllint .github/workflows .yamllint.yml
	plutil -lint config/Info.plist config/Version.plist config/entitlements.plist
	./scripts/validate-homebrew-cask.sh
	git diff --check

clean:
	swift package clean
	rm -rf build dist

package:
	SIGNING_MODE=adhoc ./scripts/package.sh release

run:
	./scripts/run-app.sh

verify: test lint package
	./scripts/run-app.sh --no-build --smoke

release-app:
	SIGNING_MODE=release APP_IDENTITY="$(APP_IDENTITY)" ./scripts/package.sh release

release-dmg:
	./scripts/create-dmg.sh "$(VERSION)"

release-cask:
	./scripts/render_homebrew_cask.sh "$(VERSION)" "$(SHA256)" "$(OUTPUT)"
