import Foundation
import Testing
@testable import SymfonyCLIMenuBar

@Suite("Symfony CLI Menu Bar Tests")
struct SymfonyCLIMenuBarTests {

    // MARK: - App Info

    @Test("AppInfo version is valid semver")
    func appInfoVersion() {
        guard AppInfo.version != "dev" else { return }
        let pattern = /^\d+\.\d+\.\d+$/
        #expect(AppInfo.version.firstMatch(of: pattern) != nil)
    }

    @Test("AppInfo build is non-empty")
    func appInfoBuild() {
        #expect(!AppInfo.build.isEmpty)
    }

    // MARK: - Path Escaping (Security)

    @Test("Single quote in path is shell-escaped")
    func pathEscapingSingleQuote() {
        let unsafePath = "~/Sites/project's-folder"
        let escaped = unsafePath.replacingOccurrences(of: "'", with: "'\\''")

        #expect(escaped.contains("'\\''"))
        #expect(escaped == "~/Sites/project'\\''s-folder")
    }

    @Test("Multiple quotes in path are all escaped")
    func pathEscapingMultipleQuotes() {
        let unsafePath = "~/Sites/'project'/'subdir'"
        let escaped = unsafePath.replacingOccurrences(of: "'", with: "'\\''")

        let quoteCount = escaped.components(separatedBy: "'\\''").count - 1
        #expect(quoteCount == 4)
    }

    @Test("Safe path remains unchanged after escaping")
    func pathEscapingNoQuotes() {
        let safePath = "~/Sites/project-folder"
        let escaped = safePath.replacingOccurrences(of: "'", with: "'\\''")

        #expect(safePath == escaped)
    }

    // MARK: - Version Parsing

    @Test("Valid semantic versions are recognized",
          arguments: ["8.4.8", "8.3.15", "7.4.33", "8.0.0"])
    func validVersionFormat(version: String) {
        let pattern = /^(\d+)\.(\d+)\.(\d+)$/
        #expect(version.firstMatch(of: pattern) != nil)
    }

    @Test("Invalid version strings are rejected",
          arguments: ["8.4", "8", "8.4.8.1", "abc", ""])
    func invalidVersionFormat(version: String) {
        let pattern = /^(\d+)\.(\d+)\.(\d+)$/
        #expect(version.firstMatch(of: pattern) == nil)
    }

    // MARK: - Domain Patterns

    @Test("Valid .wip domains match pattern",
          arguments: ["project.wip", "my-app.wip", "test123.wip"])
    func validWipDomain(domain: String) {
        let pattern = /([a-zA-Z0-9.\-]+\.wip)/
        #expect(domain.firstMatch(of: pattern) != nil)
    }

    @Test("Invalid domains do not match .wip pattern",
          arguments: [".wip", "wip", "project.com", ""])
    func invalidWipDomain(domain: String) {
        let pattern = /^([a-zA-Z0-9.\-]+\.wip)$/
        #expect(domain.firstMatch(of: pattern) == nil)
    }

    // MARK: - Server State

    @Test("Port number string indicates running server")
    func serverStateRunning() {
        #expect(Int("8000") != nil)
        #expect(Int("Not running") == nil)
    }

    // MARK: - File Paths

    @Test("Tilde is expanded to absolute path")
    func tildeExpansion() {
        let pathWithTilde = "~/Sites/project"
        let expanded = (pathWithTilde as NSString).expandingTildeInPath

        #expect(!expanded.hasPrefix("~"))
        #expect(expanded.hasPrefix("/"))
        #expect(expanded.contains("/Sites/project"))
    }

    @Test("Last path component is extracted correctly")
    func lastPathComponent() {
        let path = "/Users/test/Sites/my-project"
        let url = URL(fileURLWithPath: path)

        #expect(url.lastPathComponent == "my-project")
    }

    @Test("Last path component works with tilde expansion")
    func lastPathComponentWithTilde() {
        let path = "~/Sites/my-project"
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        #expect(url.lastPathComponent == "my-project")
    }
}

// MARK: - Server List Parsing Tests

@Suite("Server List Parsing")
struct ServerListParsingTests {

    @MainActor private func makeManager() -> SymfonyServerManager {
        SymfonyServerManager()
    }

    @Test("Empty output returns empty array")
    @MainActor func emptyOutput() {
        let manager = makeManager()
        let result = manager.parseServerListText("")
        #expect(result.isEmpty)
    }

    @Test("Single running server is parsed correctly")
    @MainActor func singleRunningServer() {
        let manager = makeManager()
        let output = """
        +-------------------------------+------+
        | Directory                     | Port |
        +-------------------------------+------+
        | /Users/john/Sites/my-project  | 8000 |
        +-------------------------------+------+
        """
        let result = manager.parseServerListText(output)

        #expect(result.count == 1)
        #expect(result[0].directory == "/Users/john/Sites/my-project")
        #expect(result[0].port == 8000)
        #expect(result[0].isRunning == true)
        #expect(result[0].url == "https://127.0.0.1:8000")
    }

    @Test("Single stopped server is parsed correctly")
    @MainActor func singleStoppedServer() {
        let manager = makeManager()
        let output = """
        +-------------------------------+-------------+
        | Directory                     | Port        |
        +-------------------------------+-------------+
        | /Users/john/Sites/my-project  | Not running |
        +-------------------------------+-------------+
        """
        let result = manager.parseServerListText(output)

        #expect(result.count == 1)
        #expect(result[0].isRunning == false)
        #expect(result[0].url == "")
    }

    @Test("Multiple servers with mixed states are parsed")
    @MainActor func multipleServersMixed() {
        let manager = makeManager()
        let output = """
        +-------------------------------+-------------+
        | Directory                     | Port        |
        +-------------------------------+-------------+
        | /Users/john/Sites/project-a   | 8000        |
        | /Users/john/Sites/project-b   | Not running |
        | /Users/john/Sites/project-c   | 8002        |
        +-------------------------------+-------------+
        """
        let result = manager.parseServerListText(output)

        #expect(result.count == 3)
        #expect(result[0].isRunning == true)
        #expect(result[0].port == 8000)
        #expect(result[1].isRunning == false)
        #expect(result[2].isRunning == true)
        #expect(result[2].port == 8002)
    }

    @Test("Tilde paths are accepted and expanded")
    @MainActor func tildePaths() {
        let manager = makeManager()
        let output = """
        +-------------------------+------+
        | Directory               | Port |
        +-------------------------+------+
        | ~/Sites/my-project      | 8000 |
        +-------------------------+------+
        """
        let result = manager.parseServerListText(output)
        let expected = ("~/Sites/my-project" as NSString).expandingTildeInPath

        #expect(result.count == 1)
        #expect(result[0].directory == expected)
        #expect(result[0].isRunning == true)
    }

    @Test("Header and separator lines are filtered out")
    @MainActor func headerFiltering() {
        let manager = makeManager()
        let output = """
        +-------------------------------+------+
        | Directory                     | Port |
        +-------------------------------+------+
        +-------------------------------+------+
        """
        let result = manager.parseServerListText(output)

        #expect(result.isEmpty)
    }

    @Test("Malformed lines without path prefix are skipped")
    @MainActor func malformedLinesSkipped() {
        let manager = makeManager()
        let output = """
        | not-a-path | 8000 |
        | /valid/path/project | 8001 |
        """
        let result = manager.parseServerListText(output)

        #expect(result.count == 1)
        #expect(result[0].directory == "/valid/path/project")
    }

    @Test("Lines without pipe separators are skipped")
    @MainActor func noPipeSeparators() {
        let manager = makeManager()
        let output = """
        Some random text without pipes
        /Users/john/Sites/project 8000
        | /Users/john/Sites/project | 8000 |
        """
        let result = manager.parseServerListText(output)

        #expect(result.count == 1)
    }

    @Test("Display name is extracted from directory")
    @MainActor func displayNameExtraction() {
        let manager = makeManager()
        let output = """
        | /Users/john/Sites/my-awesome-project | 8000 |
        """
        let result = manager.parseServerListText(output)

        #expect(result.count == 1)
        #expect(result[0].displayName == "my-awesome-project")
    }
}

// MARK: - PHP Versions Parsing Tests

@Suite("PHP Versions Parsing")
struct PHPVersionsParsingTests {

    @MainActor private func makeManager() -> SymfonyServerManager {
        SymfonyServerManager()
    }

    @Test("Empty output returns empty array")
    @MainActor func emptyOutput() {
        let manager = makeManager()
        let result = manager.parsePHPVersionsList("")
        #expect(result.isEmpty)
    }

    @Test("Single version with path is parsed")
    @MainActor func singleVersion() {
        let manager = makeManager()
        let output = """
        | 8.4.8 | /opt/homebrew/bin/php |
        """
        let result = manager.parsePHPVersionsList(output)

        #expect(result.count == 1)
        #expect(result[0].version == "8.4.8")
        #expect(result[0].path == "/opt/homebrew/bin/php")
    }

    @Test("Default version is detected via asterisk")
    @MainActor func defaultVersionAsterisk() {
        let manager = makeManager()
        let output = """
        | 8.3.15 | /opt/homebrew/bin/php83 |
        | 8.4.8 * | /opt/homebrew/bin/php |
        """
        let result = manager.parsePHPVersionsList(output)

        #expect(result.count == 2)
        #expect(result[0].isDefault == false)
        #expect(result[1].isDefault == true)
    }

    @Test("Default version is detected via 'default' keyword")
    @MainActor func defaultVersionKeyword() {
        let manager = makeManager()
        let output = """
        | 8.4.8 (default) | /opt/homebrew/bin/php |
        """
        let result = manager.parsePHPVersionsList(output)

        #expect(result.count == 1)
        #expect(result[0].isDefault == true)
    }

    @Test("Duplicate versions are deduplicated")
    @MainActor func deduplication() {
        let manager = makeManager()
        let output = """
        | 8.4.8 | /opt/homebrew/bin/php |
        | 8.4.8 | /usr/local/bin/php |
        """
        let result = manager.parsePHPVersionsList(output)

        #expect(result.count == 1)
    }

    @Test("Two-part version (8.4) is accepted")
    @MainActor func twoPartVersion() {
        let manager = makeManager()
        let output = """
        | 8.4 | /opt/homebrew/bin/php |
        """
        let result = manager.parsePHPVersionsList(output)

        #expect(result.count == 1)
        #expect(result[0].version == "8.4")
    }

    @Test("Header and border lines are skipped")
    @MainActor func headersSkipped() {
        let manager = makeManager()
        let output = """
        ┌─────────┬──────────────────────────┐
        │ Version │ Path                     │
        ├─────────┼──────────────────────────┤
        │ 8.4.8   │ /opt/homebrew/bin/php    │
        └─────────┴──────────────────────────┘
        """
        let result = manager.parsePHPVersionsList(output)

        #expect(result.count == 1)
        #expect(result[0].version == "8.4.8")
    }
}

// MARK: - Proxies Parsing Tests

@Suite("Proxies Parsing")
struct ProxiesParsingTests {

    @MainActor private func makeManager() -> SymfonyServerManager {
        SymfonyServerManager()
    }

    @Test("Empty output returns empty array")
    @MainActor func emptyOutput() {
        let manager = makeManager()
        let result = manager.parseProxiesList("")
        #expect(result.isEmpty)
    }

    @Test("Single proxy with domain and directory is parsed")
    @MainActor func singleProxy() {
        let manager = makeManager()
        let output = """
        | my-project.wip | /Users/john/Sites/my-project |
        """
        let result = manager.parseProxiesList(output)

        #expect(result.count == 1)
        #expect(result[0].domain == "my-project.wip")
        #expect(result[0].directory == "/Users/john/Sites/my-project")
    }

    @Test("Multiple proxies are parsed")
    @MainActor func multipleProxies() {
        let manager = makeManager()
        let output = """
        | project-a.wip | /Users/john/Sites/project-a |
        | project-b.wip | /Users/john/Sites/project-b |
        | project-c.wip | /Users/john/Sites/project-c |
        """
        let result = manager.parseProxiesList(output)

        #expect(result.count == 3)
    }

    @Test("Domain with hyphens and numbers is parsed")
    @MainActor func domainWithHyphensAndNumbers() {
        let manager = makeManager()
        let output = """
        | my-app-123.wip | /Users/john/Sites/my-app-123 |
        """
        let result = manager.parseProxiesList(output)

        #expect(result.count == 1)
        #expect(result[0].domain == "my-app-123.wip")
    }

    @Test("Line without directory still parses domain")
    @MainActor func missingDirectory() {
        let manager = makeManager()
        let output = """
        my-project.wip
        """
        let result = manager.parseProxiesList(output)

        #expect(result.count == 1)
        #expect(result[0].domain == "my-project.wip")
        #expect(result[0].directory == "")
    }
}

// MARK: - Display Name Tests

@Suite("Display Name")
struct DisplayNameTests {

    @Test("Display name is last path component")
    func displayNameFromPath() {
        let server = SymfonyServer(
            id: "test",
            directory: "/Users/john/Sites/my-project",
            port: 8000, url: "", isRunning: true,
            pid: nil, phpVersion: nil, ssl: true, lastSeen: 0
        )
        #expect(server.displayName == "my-project")
    }

    @Test("Display name handles hyphens and dots")
    func displayNameHyphensDots() {
        let server = SymfonyServer(
            id: "test",
            directory: "/Users/john/Sites/my-app.v2",
            port: 8000, url: "", isRunning: true,
            pid: nil, phpVersion: nil, ssl: true, lastSeen: 0
        )
        #expect(server.displayName == "my-app.v2")
    }

    @Test("Display name for single-component path")
    func displayNameSingleComponent() {
        let server = SymfonyServer(
            id: "test",
            directory: "project",
            port: 8000, url: "", isRunning: true,
            pid: nil, phpVersion: nil, ssl: true, lastSeen: 0
        )
        #expect(server.displayName == "project")
    }

    @Test("Display name falls back to id when directory is empty")
    func displayNameFallback() {
        let server = SymfonyServer(
            id: "fallback-id",
            directory: "",
            port: 8000, url: "", isRunning: true,
            pid: nil, phpVersion: nil, ssl: true, lastSeen: 0
        )
        #expect(server.displayName == "fallback-id")
    }
}

// MARK: - CLI Version Regex Tests

@Suite("CLI Version Regex")
struct CLIVersionRegexTests {

    @Test("Standard version string matches")
    func standardVersion() {
        let output = "Symfony CLI version 5.12.0"
        let match = output.firstMatch(of: /(?i)version\s+([\d.]+)/)
        #expect(match != nil)
        #expect(String(match!.1) == "5.12.0")
    }

    @Test("Case-insensitive matching works")
    func caseInsensitive() {
        let output = "Symfony CLI VERSION 5.12.0"
        let match = output.firstMatch(of: /(?i)version\s+([\d.]+)/)
        #expect(match != nil)
        #expect(String(match!.1) == "5.12.0")
    }

    @Test("No version keyword means no match")
    func noVersionKeyword() {
        let output = "Symfony CLI 5.12.0"
        let match = output.firstMatch(of: /(?i)version\s+([\d.]+)/)
        #expect(match == nil)
    }
}

// MARK: - Optimistic Update Tests

@Suite("Optimistic Server State Updates")
struct OptimisticUpdateTests {

    private func makeServer(directory: String, isRunning: Bool) -> SymfonyServer {
        SymfonyServer(
            id: directory,
            directory: directory, port: 8000, url: "", isRunning: isRunning,
            pid: nil, phpVersion: nil, ssl: true, lastSeen: 0
        )
    }

    @Test("Mark stopped server as running")
    @MainActor func markStoppedAsRunning() {
        let manager = SymfonyServerManager()
        let dir = "/Users/john/Sites/my-project"
        manager.servers = [makeServer(directory: dir, isRunning: false)]

        manager.optimisticallyMark(directory: dir, running: true)

        #expect(manager.servers[0].isRunning == true)
    }

    @Test("Mark running server as stopped")
    @MainActor func markRunningAsStopped() {
        let manager = SymfonyServerManager()
        let dir = "/Users/john/Sites/my-project"
        manager.servers = [makeServer(directory: dir, isRunning: true)]

        manager.optimisticallyMark(directory: dir, running: false)

        #expect(manager.servers[0].isRunning == false)
    }

    @Test("Only the matching server is updated")
    @MainActor func onlyMatchingServerUpdated() {
        let manager = SymfonyServerManager()
        let targetDir = "/Users/john/Sites/target"
        let otherDir  = "/Users/john/Sites/other"
        manager.servers = [
            makeServer(directory: targetDir, isRunning: false),
            makeServer(directory: otherDir,  isRunning: false),
        ]

        manager.optimisticallyMark(directory: targetDir, running: true)

        #expect(manager.servers.first { $0.directory == targetDir }?.isRunning == true)
        #expect(manager.servers.first { $0.directory == otherDir  }?.isRunning == false)
    }

    @Test("Tilde path is normalised and matches expanded path")
    @MainActor func tildePathNormalised() {
        let manager = SymfonyServerManager()
        let home = (("~") as NSString).expandingTildeInPath
        let expandedDir = "\(home)/Sites/my-project"
        manager.servers = [makeServer(directory: expandedDir, isRunning: false)]

        // Call with tilde form — should still match
        manager.optimisticallyMark(directory: "~/Sites/my-project", running: true)

        #expect(manager.servers[0].isRunning == true)
    }

    @Test("Unknown directory leaves all servers unchanged")
    @MainActor func unknownDirectoryIsNoOp() {
        let manager = SymfonyServerManager()
        let dir = "/Users/john/Sites/my-project"
        manager.servers = [makeServer(directory: dir, isRunning: false)]

        manager.optimisticallyMark(directory: "/Users/john/Sites/unknown", running: true)

        #expect(manager.servers[0].isRunning == false)
    }

    @Test("All other server properties are preserved after optimistic update")
    @MainActor func serverPropertiesPreserved() {
        let manager = SymfonyServerManager()
        let dir = "/Users/john/Sites/my-project"
        let ts: TimeInterval = 1_700_000_000
        manager.servers = [
            SymfonyServer(id: "custom-id", directory: dir,
                          port: 9000, url: "https://127.0.0.1:9000", isRunning: false,
                          pid: 42, phpVersion: "8.3", ssl: true, lastSeen: ts)
        ]

        manager.optimisticallyMark(directory: dir, running: true)

        let updated = manager.servers[0]
        #expect(updated.id          == "custom-id")
        #expect(updated.port        == 9000)
        #expect(updated.pid         == 42)
        #expect(updated.phpVersion  == "8.3")
        #expect(updated.lastSeen    == ts)
        #expect(updated.isRunning   == true)
    }
}

// MARK: - mergeWithKnownServers Tests

// Serialized because every test writes to UserDefaults.standard — concurrent
// execution would cause races and index-out-of-range crashes in assertions.
@Suite("Known Server Merging", .serialized)
struct KnownServerMergingTests {

    private let udKey = "KnownServerDirectories"

    @MainActor private func makeManager() -> SymfonyServerManager {
        SymfonyServerManager()
    }

    private func makeServer(directory: String, isRunning: Bool = true) -> SymfonyServer {
        SymfonyServer(
            id: directory,
            directory: directory, port: 8000, url: isRunning ? "https://127.0.0.1:8000" : "",
            isRunning: isRunning, pid: nil, phpVersion: nil, ssl: true, lastSeen: 0
        )
    }

    private func seedTimestamps(_ timestamps: [String: TimeInterval]) {
        UserDefaults.standard.set(timestamps, forKey: udKey)
    }

    private func clearTimestamps() {
        UserDefaults.standard.removeObject(forKey: udKey)
    }

    // Reset before AND after: protects against dirty state from a prior test
    // even if the suite runs in a fresh process that reuses the same defaults.
    private func isolate(_ body: () throws -> Void) rethrows {
        clearTimestamps()
        defer { clearTimestamps() }
        try body()
    }

    // MARK: Fetched server stamping

    @Test("Fetched server lastSeen is stamped with current time")
    @MainActor func fetchedServerGetsTimestamp() throws {
        try isolate {
            let manager = makeManager()
            let before = Date().timeIntervalSince1970

            let result = manager.mergeWithKnownServers([makeServer(directory: "/Sites/a")])

            try #require(result.count == 1)
            #expect(result[0].lastSeen >= before)
        }
    }

    @Test("Fetched running server isRunning is preserved as true")
    @MainActor func fetchedRunningServerPreserved() throws {
        try isolate {
            let manager = makeManager()
            let result = manager.mergeWithKnownServers([makeServer(directory: "/Sites/a", isRunning: true)])

            try #require(result.count == 1)
            #expect(result[0].isRunning == true)
        }
    }

    @Test("Fetched stopped server isRunning is preserved as false")
    @MainActor func fetchedStoppedServerPreserved() throws {
        try isolate {
            let manager = makeManager()
            let result = manager.mergeWithKnownServers([makeServer(directory: "/Sites/b", isRunning: false)])

            try #require(result.count == 1)
            #expect(result[0].isRunning == false)
        }
    }

    // MARK: Synthetic stopped entries

    @Test("Known directory absent from fetch becomes a synthetic stopped entry")
    @MainActor func absentDirectoryCreatesSyntheticEntry() throws {
        try isolate {
            let ts = Date().timeIntervalSince1970
            seedTimestamps(["/Sites/known": ts])
            let manager = makeManager()

            let result = manager.mergeWithKnownServers([])

            try #require(result.count == 1)
            #expect(result[0].directory == "/Sites/known")
            #expect(result[0].isRunning == false)
        }
    }

    @Test("Synthetic entry preserves its stored lastSeen timestamp")
    @MainActor func syntheticEntryPreservesTimestamp() throws {
        try isolate {
            // Must be within the 30-day retention window
            let stored = Date().timeIntervalSince1970 - (7 * 86_400)
            seedTimestamps(["/Sites/known": stored])
            let manager = makeManager()

            let result = manager.mergeWithKnownServers([])

            try #require(result.count == 1)
            #expect(result[0].lastSeen == stored)
        }
    }

    @Test("Fetched directory is not duplicated as a synthetic entry")
    @MainActor func fetchedDirNotDuplicated() {
        isolate {
            let ts = Date().timeIntervalSince1970
            seedTimestamps(["/Sites/a": ts])
            let manager = makeManager()

            let result = manager.mergeWithKnownServers([makeServer(directory: "/Sites/a")])

            // Only the stamped fetched entry; no duplicate synthetic entry
            #expect(result.count == 1)
        }
    }

    @Test("Result combines fetched (running) and synthetic (stopped) entries")
    @MainActor func resultCombinesBothKinds() {
        isolate {
            let ts = Date().timeIntervalSince1970
            seedTimestamps(["/Sites/known": ts])
            let manager = makeManager()

            let result = manager.mergeWithKnownServers([makeServer(directory: "/Sites/live", isRunning: true)])

            #expect(result.count == 2)
            #expect(result.filter {  $0.isRunning }.count == 1)
            #expect(result.filter { !$0.isRunning }.count == 1)
        }
    }

    // MARK: Retention cutoff

    @Test("Entry older than 30 days is pruned")
    @MainActor func staleEntryPruned() {
        isolate {
            let staleTs = Date().timeIntervalSince1970 - (31 * 86_400)
            seedTimestamps(["/Sites/old": staleTs])
            let manager = makeManager()

            let result = manager.mergeWithKnownServers([])

            #expect(result.isEmpty)
        }
    }

    @Test("Entry exactly 29 days old is kept")
    @MainActor func freshEnoughEntryKept() {
        isolate {
            let recentTs = Date().timeIntervalSince1970 - (29 * 86_400)
            seedTimestamps(["/Sites/recent": recentTs])
            let manager = makeManager()

            let result = manager.mergeWithKnownServers([])

            #expect(result.count == 1)
        }
    }

    // MARK: Max count cap

    @Test("More than 10 known entries are capped at 10")
    @MainActor func maxCountEnforced() {
        isolate {
            let now = Date().timeIntervalSince1970
            var timestamps: [String: TimeInterval] = [:]
            for i in 1...12 {
                timestamps["/Sites/project-\(i)"] = now - Double(i)
            }
            seedTimestamps(timestamps)
            let manager = makeManager()

            let result = manager.mergeWithKnownServers([])

            #expect(result.count <= 10)
        }
    }

    @Test("When capped, the most recently seen entries are kept")
    @MainActor func capKeepsMostRecent() {
        isolate {
            let now = Date().timeIntervalSince1970
            var timestamps: [String: TimeInterval] = [:]
            for i in 1...12 {
                timestamps["/Sites/project-\(i)"] = now - Double(i * 100)
            }
            // project-1 is newest (now - 100), project-12 is oldest (now - 1200)
            seedTimestamps(timestamps)
            let manager = makeManager()

            let result = manager.mergeWithKnownServers([])

            #expect(result.count == 10)
            let dirs = result.map { $0.directory }
            #expect(!dirs.contains("/Sites/project-11"))
            #expect(!dirs.contains("/Sites/project-12"))
        }
    }

    // MARK: Tilde path handling

    @Test("Synthetic entry for tilde-keyed directory uses expanded path")
    @MainActor func syntheticEntryExpandsTilde() throws {
        try isolate {
            let ts = Date().timeIntervalSince1970
            seedTimestamps(["~/Sites/tilde-project": ts])
            let manager = makeManager()
            let expected = ("~/Sites/tilde-project" as NSString).expandingTildeInPath

            let result = manager.mergeWithKnownServers([])

            try #require(result.count == 1)
            #expect(result[0].directory == expected)
            #expect(!result[0].directory.hasPrefix("~"))
        }
    }
}

// MARK: - Server List Parsing Edge Cases

@Suite("Server List Parsing Edge Cases")
struct ServerListEdgeCaseTests {

    @MainActor private func makeManager() -> SymfonyServerManager { SymfonyServerManager() }

    @Test("URL for running server uses correct non-default port")
    @MainActor func urlUsesCorrectPort() throws {
        let manager = makeManager()
        let result = manager.parseServerListText("| /Sites/project | 9001 |")

        try #require(result.count == 1)
        #expect(result[0].port == 9001)
        #expect(result[0].url == "https://127.0.0.1:9001")
    }

    @Test("Stopped server has empty URL")
    @MainActor func stoppedServerHasEmptyURL() throws {
        let manager = makeManager()
        let result = manager.parseServerListText("| /Sites/project | Not running |")

        try #require(result.count == 1)
        #expect(result[0].url == "")
        #expect(result[0].port == 8000)
    }

    @Test("Port column case-insensitive: NOT RUNNING treated as stopped")
    @MainActor func notRunningCaseInsensitive() throws {
        let manager = makeManager()
        let variants = [
            "| /Sites/a | NOT RUNNING |",
            "| /Sites/b | Not Running |",
            "| /Sites/c | not running |",
        ]
        for line in variants {
            let result = manager.parseServerListText(line)
            try #require(result.count == 1, "expected 1 result for: \(line)")
            #expect(result[0].isRunning == false, "expected stopped for: \(line)")
        }
    }

    @Test("Line with only one column is skipped")
    @MainActor func singleColumnSkipped() {
        let manager = makeManager()
        let result = manager.parseServerListText("| /Sites/project |")
        #expect(result.isEmpty)
    }
}

// MARK: - PHP Versions Parsing Edge Cases

@Suite("PHP Versions Parsing Edge Cases")
struct PHPVersionsEdgeCaseTests {

    @MainActor private func makeManager() -> SymfonyServerManager { SymfonyServerManager() }

    @Test("Star emoji marks version as default")
    @MainActor func starEmojiIsDefault() throws {
        let manager = makeManager()
        let result = manager.parsePHPVersionsList("| 8.4.8 ⭐ | /opt/homebrew/bin/php |")

        try #require(result.count == 1)
        #expect(result[0].isDefault == true)
    }

    @Test("Version line with no path yields empty path string")
    @MainActor func versionWithoutPath() throws {
        let manager = makeManager()
        let result = manager.parsePHPVersionsList("| 8.4.8 |")

        try #require(result.count == 1)
        #expect(result[0].version == "8.4.8")
        #expect(result[0].path == "")
    }

    @Test("Lines with unicode box-drawing borders are skipped")
    @MainActor func unicodeBordersSkipped() throws {
        let manager = makeManager()
        let output = """
        ┌─────────┬───────────────────────┐
        │ Version │ Path                  │
        ├─────────┼───────────────────────┤
        │ 8.4.8   │ /opt/homebrew/bin/php │
        └─────────┴───────────────────────┘
        """
        let result = manager.parsePHPVersionsList(output)

        try #require(result.count == 1)
        #expect(result[0].version == "8.4.8")
    }

    @Test("Duplicate version across two paths is deduplicated")
    @MainActor func duplicatesAcrossPathsDeduplicated() {
        let manager = makeManager()
        let output = """
        | 8.4.8 | /opt/homebrew/bin/php |
        | 8.4.8 | /usr/local/bin/php    |
        """
        let result = manager.parsePHPVersionsList(output)

        #expect(result.count == 1)
    }
}

// MARK: - Proxy Parsing Edge Cases

@Suite("Proxy Parsing Edge Cases")
struct ProxyParsingEdgeCaseTests {

    @MainActor private func makeManager() -> SymfonyServerManager { SymfonyServerManager() }

    @Test("Duplicate domain on separate lines is deduplicated")
    @MainActor func duplicateDomainDeduplicated() throws {
        let manager = makeManager()
        let output = """
        | project.wip | /Sites/project-v1 |
        | project.wip | /Sites/project-v2 |
        """
        let result = manager.parseProxiesList(output)

        try #require(result.count == 1)
        #expect(result[0].domain == "project.wip")
    }

    @Test("Proxy directory with tilde is parsed")
    @MainActor func proxyWithTildePath() throws {
        let manager = makeManager()
        let result = manager.parseProxiesList("| my-app.wip | ~/Sites/my-app |")

        try #require(result.count == 1)
        #expect(result[0].directory == "~/Sites/my-app")
    }

    @Test("All parsed proxies are marked active")
    @MainActor func parsedProxiesAreActive() {
        let manager = makeManager()
        let output = """
        | alpha.wip | /Sites/alpha |
        | beta.wip  | /Sites/beta  |
        """
        let result = manager.parseProxiesList(output)

        #expect(result.allSatisfy { $0.isActive })
    }

    @Test("Header lines containing Domain or Directory are skipped")
    @MainActor func headerLinesSkipped() throws {
        let manager = makeManager()
        let output = """
        +----------------+----------------------+
        | Domain         | Directory            |
        +----------------+----------------------+
        | my-project.wip | /Sites/my-project    |
        +----------------+----------------------+
        """
        let result = manager.parseProxiesList(output)

        try #require(result.count == 1)
        #expect(result[0].domain == "my-project.wip")
    }
}

// MARK: - CLI Not Found Tests

@Suite("CLI Not Found")
struct CLINotFoundTests {

    @Test("refreshServersAsync sets lastError when CLI path is nil")
    @MainActor func refreshSetsErrorWhenNoCLI() async {
        let manager = SymfonyServerManager()
        manager.symfonyCliPath = nil

        await manager.refreshServersAsync()

        #expect(manager.lastError == "Symfony CLI not found")
    }

    @Test("refreshServersAsync empties servers when CLI path is nil")
    @MainActor func refreshEmptiesServersWhenNoCLI() async {
        let manager = SymfonyServerManager()
        manager.symfonyCliPath = nil
        manager.servers = [
            SymfonyServer(id: "a", directory: "/Sites/a",
                          port: 8000, url: "", isRunning: true,
                          pid: nil, phpVersion: nil, ssl: true, lastSeen: 0)
        ]

        await manager.refreshServersAsync()

        #expect(manager.servers.isEmpty)
    }

    @Test("refreshServersAsync clears lastError when CLI is available")
    @MainActor func refreshClearsErrorWhenCLIFound() async {
        let manager = SymfonyServerManager()
        manager.lastError = "Symfony CLI not found"
        // Only run if CLI is actually present on this machine
        guard manager.symfonyCliPath != nil else { return }

        await manager.refreshServersAsync()

        #expect(manager.lastError == nil)
    }

    @Test("AppInfo.symfonyCliURL is a valid URL")
    func symfonyCliURLIsValid() {
        let url = URL(string: AppInfo.symfonyCliURL)
        #expect(url != nil)
        #expect(url?.scheme == "https")
    }
}

// MARK: - FIX 12: cap+fetch interaction in mergeWithKnownServers

@Suite("Known Server Cap and Fetch Interaction", .serialized)
struct KnownServerCapFetchTests {

    private let udKey = "KnownServerDirectories"

    @MainActor private func makeManager() -> SymfonyServerManager {
        SymfonyServerManager()
    }

    private func makeServer(directory: String) -> SymfonyServer {
        SymfonyServer(
            id: directory,
            directory: directory, port: 8000, url: "https://127.0.0.1:8000",
            isRunning: true, pid: nil, phpVersion: nil, ssl: true, lastSeen: 0
        )
    }

    private func clearTimestamps() {
        UserDefaults.standard.removeObject(forKey: udKey)
    }

    @Test("10 known entries plus 1 new fetched server evicts the oldest known entry")
    @MainActor func capPlusFetchEvictsOldest() throws {
        clearTimestamps()
        defer { clearTimestamps() }

        let now = Date().timeIntervalSince1970
        // Seed 10 known entries with decreasing timestamps (oldest = project-10)
        var timestamps: [String: TimeInterval] = [:]
        for i in 1...10 {
            timestamps["/Sites/stored-\(i)"] = now - Double(i * 100)
        }
        UserDefaults.standard.set(timestamps, forKey: udKey)

        let manager = makeManager()
        // Pass in 1 new fetched server that is not in the stored list
        let fetched = [makeServer(directory: "/Sites/new-project")]
        let result = manager.mergeWithKnownServers(fetched)

        // Total known after merge must not exceed the max cap of 10
        #expect(result.count == 10)

        // The newly fetched server must be present
        let dirs = result.map { $0.directory }
        #expect(dirs.contains("/Sites/new-project"))

        // The oldest stored entry should have been evicted
        #expect(!dirs.contains("/Sites/stored-10"))
    }
}

// MARK: - FIX 13: ASCII-pipe PHP header row

@Suite("PHP Versions Parsing ASCII Pipe Header")
struct PHPVersionsASCIIPipeTests {

    @MainActor private func makeManager() -> SymfonyServerManager {
        SymfonyServerManager()
    }

    @Test("ASCII-pipe header row with Version and Path is skipped")
    @MainActor func asciiPipeHeaderSkipped() throws {
        let manager = makeManager()
        let output = """
        +---------+--------------------------+
        | Version | Path                     |
        +---------+--------------------------+
        | 8.4.8   | /opt/homebrew/bin/php    |
        +---------+--------------------------+
        """
        let result = manager.parsePHPVersionsList(output)

        try #require(result.count == 1)
        #expect(result[0].version == "8.4.8")
    }
}
