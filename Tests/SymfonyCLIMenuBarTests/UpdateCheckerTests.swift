import Foundation
import Testing

@testable import SymfonyCLIMenuBar

@Suite("Application versions")
struct AppVersionTests {
    @Test("Accepts stable semantic versions with an optional v prefix")
    func acceptsSemanticVersions() {
        #expect(AppVersion("1.0.0")?.rawValue == "1.0.0")
        #expect(AppVersion("v1.2.3")?.rawValue == "1.2.3")
    }

    @Test(
        "Rejects malformed and prerelease versions",
        arguments: ["dev", "1.2", "1.2.3.4", "1.two.3", "+1.0.0", "1.0.0-beta.1"])
    func rejectsMalformedVersions(_ value: String) {
        #expect(AppVersion(value) == nil)
    }

    @Test("Compares numeric components")
    func comparesNumericComponents() throws {
        let older = try #require(AppVersion("0.9.9"))
        let newer = try #require(AppVersion("1.0.0"))

        #expect(older < newer)
    }
}

@Suite("Update checker")
struct UpdateCheckerTests {
    @Test("Parses the published version from a Homebrew cask")
    func parsesPublishedCask() throws {
        let release = try UpdateChecker.parsePublishedRelease(
            from: """
                cask "symfony-cli-menubar" do
                  version "1.0.0"
                  sha256 "abc"
                end
                """)

        #expect(release.version == AppVersion("1.0.0"))
        #expect(release.releaseURL.absoluteString == "https://github.com/smnandre/symfony-cli-menubar/releases/tag/v1.0.0")
    }

    @Test("Reports a newer published cask")
    func reportsAvailableUpdate() async throws {
        let release = try makeRelease(version: "1.0.1")
        let checker = UpdateChecker(fetchPublishedRelease: { release })

        let result = try await checker.check(currentVersion: "1.0.0")

        #expect(result == .updateAvailable(release))
    }

    @Test("Treats the current and older casks as up to date", arguments: ["1.0.0", "0.10.3"])
    func reportsUpToDate(_ version: String) async throws {
        let release = try makeRelease(version: version)
        let checker = UpdateChecker(fetchPublishedRelease: { release })

        let result = try await checker.check(currentVersion: "1.0.0")

        #expect(result == .upToDate(release))
    }

    @Test("Reads update results from local cask fixtures")
    func readsLocalFixtures() async throws {
        let cases: [(fixture: String, version: String, available: Bool)] = [
            ("older.rb", "0.10.3", false),
            ("current.rb", "1.0.0", false),
            ("newer.rb", "1.1.0", true),
        ]

        for testCase in cases {
            let release = try makeRelease(version: testCase.version)
            let checker = UpdateChecker.live(caskURL: fixtureURL(testCase.fixture))
            let result = try await checker.check(currentVersion: "1.0.0")
            let expected: UpdateCheckResult = testCase.available ? .updateAvailable(release) : .upToDate(release)

            #expect(result == expected)
        }
    }

    @Test("Rejects an invalid local cask fixture")
    func rejectsInvalidLocalFixture() async {
        let checker = UpdateChecker.live(caskURL: fixtureURL("invalid.rb"))

        await #expect(throws: UpdateChecker.CheckError.self) {
            try await checker.check(currentVersion: "1.0.0")
        }
    }

    @Test("Rejects a missing local cask fixture")
    func rejectsMissingLocalFixture() async {
        let checker = UpdateChecker.live(caskURL: fixtureURL("missing.rb"))

        await #expect(throws: UpdateChecker.CheckError.self) {
            try await checker.check(currentVersion: "1.0.0")
        }
    }

    @Test("Rejects a cask without a stable version")
    func rejectsInvalidCask() {
        #expect(throws: UpdateChecker.CheckError.self) {
            try UpdateChecker.parsePublishedRelease(from: "version \"1.0.0-beta.1\"")
        }
    }

    private func makeRelease(version: String) throws -> PublishedCaskRelease {
        let appVersion = try #require(AppVersion(version))
        let url = try #require(URL(string: "https://github.com/smnandre/symfony-cli-menubar/releases/tag/v\(version)"))
        return PublishedCaskRelease(version: appVersion, releaseURL: url)
    }

    private func fixtureURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/UpdateCasks")
            .appendingPathComponent(name)
    }
}

@Suite("Update presentation")
struct UpdatePresentationTests {
    @Test("Presents an available Homebrew update")
    func presentsAvailableUpdate() throws {
        let release = try makeRelease(version: "1.1.0")
        let presentation = UpdatePresentation(
            result: .updateAvailable(release),
            homebrewCommand: "brew upgrade --cask symfony-cli-menubar")

        #expect(presentation.messageText == "Update Available")
        #expect(presentation.informativeText.contains("Version 1.1.0 is available."))
        #expect(presentation.informativeText.contains("brew upgrade --cask symfony-cli-menubar"))
    }

    @Test("Does not claim a local build is the latest release")
    func presentsNoAvailableUpdate() throws {
        let release = try makeRelease(version: "0.10.3")
        let presentation = UpdatePresentation(
            result: .upToDate(release),
            homebrewCommand: "brew upgrade --cask symfony-cli-menubar")

        #expect(presentation.messageText == "You're Up to Date")
        #expect(presentation.informativeText == "No Homebrew update is available.")
    }

    private func makeRelease(version: String) throws -> PublishedCaskRelease {
        let appVersion = try #require(AppVersion(version))
        let url = try #require(URL(string: "https://github.com/smnandre/symfony-cli-menubar/releases/tag/v\(version)"))
        return PublishedCaskRelease(version: appVersion, releaseURL: url)
    }
}
