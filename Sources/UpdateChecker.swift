// Symfony CLI Menu Bar
// Copyright © 2026 Simon André <smn.andre@gmail.com>
// Open source software - MIT License

import Foundation

struct AppVersion: Comparable, Equatable, Sendable {
    let rawValue: String

    private let components: [Int]

    init?(_ value: String) {
        let normalized = value.hasPrefix("v") ? String(value.dropFirst()) : value
        guard normalized.wholeMatch(of: /^[0-9]+\.[0-9]+\.[0-9]+$/) != nil else { return nil }
        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)

        let components = parts.compactMap { Int($0) }
        guard components.count == parts.count else { return nil }

        self.rawValue = normalized
        self.components = components
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}

struct PublishedCaskRelease: Equatable, Sendable {
    let version: AppVersion
    let releaseURL: URL
}

enum UpdateCheckResult: Equatable, Sendable {
    case updateAvailable(PublishedCaskRelease)
    case upToDate(PublishedCaskRelease)
}

struct UpdatePresentation: Equatable, Sendable {
    let messageText: String
    let informativeText: String

    init(result: UpdateCheckResult, homebrewCommand: String) {
        switch result {
        case .updateAvailable(let release):
            messageText = "Update Available"
            informativeText =
                "Version \(release.version.rawValue) is available.\n\nUpdate with Homebrew:\n\(homebrewCommand)"
        case .upToDate:
            messageText = "You're Up to Date"
            informativeText = "No Homebrew update is available."
        }
    }
}

struct UpdateChecker: Sendable {
    enum CheckError: LocalizedError {
        case invalidCurrentVersion(String)
        case invalidCask
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .invalidCurrentVersion(let version):
                "The installed version '\(version)' is invalid."
            case .invalidCask:
                "The published Homebrew cask does not contain a valid stable version."
            case .invalidResponse:
                "The Homebrew tap returned an invalid response."
            }
        }
    }

    var fetchPublishedRelease: @Sendable () async throws -> PublishedCaskRelease

    func check(currentVersion: String) async throws -> UpdateCheckResult {
        guard let current = AppVersion(currentVersion) else {
            throw CheckError.invalidCurrentVersion(currentVersion)
        }

        let release = try await fetchPublishedRelease()

        return current < release.version ? .updateAvailable(release) : .upToDate(release)
    }

    static func parsePublishedRelease(from cask: String) throws -> PublishedCaskRelease {
        let versionPattern = /^\s*version\s+"([^"]+)"\s*$/

        for line in cask.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let match = line.firstMatch(of: versionPattern) else { continue }
            let rawVersion = String(match.1)
            guard let version = AppVersion(rawVersion),
                let releaseURL = URL(string: "\(AppInfo.githubURL)/releases/tag/v\(version.rawValue)")
            else {
                throw CheckError.invalidCask
            }

            return PublishedCaskRelease(version: version, releaseURL: releaseURL)
        }

        throw CheckError.invalidCask
    }
}

extension UpdateChecker {
    static func live(caskURL: URL) -> UpdateChecker {
        UpdateChecker {
            if caskURL.isFileURL {
                let cask: String
                do {
                    cask = try String(contentsOf: caskURL, encoding: .utf8)
                } catch {
                    throw CheckError.invalidResponse
                }

                return try parsePublishedRelease(from: cask)
            }

            var request = URLRequest(url: caskURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
            request.setValue("text/plain", forHTTPHeaderField: "Accept")
            request.setValue("SymfonyCLIMenuBar", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200
            else {
                throw CheckError.invalidResponse
            }

            guard let cask = String(data: data, encoding: .utf8) else {
                throw CheckError.invalidResponse
            }

            return try parsePublishedRelease(from: cask)
        }
    }
}
