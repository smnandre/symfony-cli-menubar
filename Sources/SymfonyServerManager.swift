// Symfony CLI Menu Bar
// Copyright © 2026 Simon André <smn.andre@gmail.com>
// Open source software — MIT License
//
// "Symfony" is a registered trademark of Symfony SAS, used with kind permission.
// This app is not affiliated with or endorsed by Symfony SAS or SensioLabs.


import AppKit
import os
import OSLog

// MARK: - File-level logger (accessible from nonisolated contexts)

private let logger = Logger(subsystem: "com.simonandre.SymfonyCLIMenuBar", category: "ServerManager")

// MARK: - Models

/// Represents a Symfony local server instance
struct SymfonyServer: Identifiable, Equatable, Sendable {
    let id: String
    let directory: String
    let port: Int
    let url: String
    let isRunning: Bool
    let pid: Int?
    let phpVersion: String?
    let ssl: Bool
    let lastSeen: TimeInterval

    var displayName: String {
        let components = directory.split(separator: "/")
        return components.last.map(String.init) ?? id
    }
}

/// Represents a PHP version installed
struct PHPVersion: Identifiable, Equatable, Sendable {
    let id: String
    let version: String
    let path: String
    let isDefault: Bool
}

/// Represents a Symfony proxy (.wip domain)
struct SymfonyProxy: Identifiable, Equatable, Sendable {
    let id: String
    let domain: String
    let directory: String
    let isActive: Bool
}

// MARK: - Server Manager

/// Manages Symfony local servers, PHP versions, and proxies
@MainActor
class SymfonyServerManager: ObservableObject {
    @Published var servers: [SymfonyServer] = []
    @Published var phpVersions: [PHPVersion] = []
    @Published var proxies: [SymfonyProxy] = []
    @Published var isProxyRunning: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var symfonyCliPath: String?
    @Published var symfonyCliVersion: String?

    private let fileManager = FileManager.default

    init() {
        detectSymfonyCliFromPaths()
    }

    private func detectSymfonyCliFromPaths() {
        let possiblePaths = [
            "/usr/local/bin/symfony",
            "/opt/homebrew/bin/symfony",
            "\(NSHomeDirectory())/.symfony5/bin/symfony",
            "\(NSHomeDirectory())/.symfony/bin/symfony"
        ]
        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                symfonyCliPath = path
                return
            }
        }
    }

    func setupAsync() async {
        // Async `which symfony` fallback if hardcoded paths didn't find it
        if symfonyCliPath == nil {
            let result = await runCommand("/usr/bin/which", arguments: ["symfony"])
            if let path = result.output?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty, fileManager.fileExists(atPath: path) {
                symfonyCliPath = path
            }
        }
        guard let cliPath = symfonyCliPath else {
            lastError = "Symfony CLI not found"
            return
        }
        // Detect version
        let versionResult = await runCommand(cliPath, arguments: ["version", "--no-ansi"])
        if let output = versionResult.output,
           let match = output.firstMatch(of: /(?i)version\s+([\d.]+)/) {
            symfonyCliVersion = "CLI " + String(match.1)
        }
        logger.info("Loading initial data from Symfony CLI...")
        isLoading = true
        lastError = nil
        let data = await fetchAllData(cliPath: cliPath)
        self.isLoading = false
        self.servers = mergeWithKnownServers(data.servers)
        self.phpVersions = data.php
        self.proxies = data.proxies
        self.isProxyRunning = data.proxyRunning
        logger.info("Found \(data.servers.count) servers, \(data.php.count) PHP versions, \(data.proxies.count) proxies")
    }

    private struct FetchResult: Sendable {
        let servers: [SymfonyServer]
        let php: [PHPVersion]
        let proxies: [SymfonyProxy]
        let proxyRunning: Bool
    }

    private func fetchAllData(cliPath: String) async -> FetchResult {
        async let serversList = fetchServerList(cliPath: cliPath)
        async let phpList = fetchPHPVersions(cliPath: cliPath)
        async let proxyResult = fetchProxies(cliPath: cliPath)
        let (s, php, pr) = await (serversList, phpList, proxyResult)
        return FetchResult(servers: s, php: php, proxies: pr.list, proxyRunning: pr.running)
    }

    // MARK: - Refresh All Data

    func refreshServers() {
        Task {
            await refreshServersAsync()
        }
    }

    func refreshServersAsync() async {
        guard let cliPath = symfonyCliPath else {
            lastError = "Symfony CLI not found"
            servers = []
            return
        }

        isLoading = true
        lastError = nil

        let data = await fetchAllData(cliPath: cliPath)

        self.isLoading = false
        self.servers = mergeWithKnownServers(data.servers)
        self.phpVersions = data.php
        self.proxies = data.proxies
        self.isProxyRunning = data.proxyRunning
    }

    // MARK: - Fetch Server List

    nonisolated private func fetchServerList(cliPath: String) async -> [SymfonyServer] {
        let result = await runCommand(cliPath, arguments: ["server:list", "--no-ansi"])

        guard let output = result.output, result.exitCode == 0 else {
            logger.warning("Failed to fetch server list (exit code: \(result.exitCode))")
            return []
        }

        return parseServerListText(output)
    }

    nonisolated func parseServerListText(_ output: String) -> [SymfonyServer] {
        var parsedServers: [SymfonyServer] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            // Skip header, separator and empty lines
            if trimmed.isEmpty ||
               trimmed.hasPrefix("+") ||
               trimmed.hasPrefix("-") ||
               trimmed.contains("Directory") ||
               trimmed.contains("Port") ||
               !trimmed.contains("|") {
                continue
            }

            // Parse columns separated by |
            let columns = trimmed.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
                .filter { !$0.isEmpty }

            // Need at least directory and port columns
            guard columns.count >= 2 else { continue }

            let rawDirectory = columns[0]

            // Skip if doesn't look like a path
            guard rawDirectory.hasPrefix("/") || rawDirectory.hasPrefix("~") else { continue }

            // Always store expanded paths so keys are consistent across comparisons
            let directory = (rawDirectory as NSString).expandingTildeInPath

            // Parse port column - could be a number (running) or "Not running"
            let portColumn = columns[1]
            var port = 8000
            var isRunning = false

            if portColumn.lowercased() == "not running" {
                isRunning = false
            } else if let portNum = Int(portColumn) {
                port = portNum
                isRunning = true
            }

            // Build URL
            let url = isRunning ? "https://127.0.0.1:\(port)" : ""

            let server = SymfonyServer(
                id: directory,
                directory: directory,
                port: port,
                url: url,
                isRunning: isRunning,
                pid: nil,
                phpVersion: nil,
                ssl: true,
                lastSeen: 0
            )
            parsedServers.append(server)
        }

        return parsedServers
    }

    // MARK: - Fetch PHP Versions

    nonisolated private func fetchPHPVersions(cliPath: String) async -> [PHPVersion] {
        let result = await runCommand(cliPath, arguments: ["local:php:list", "--no-ansi"])

        guard let output = result.output, result.exitCode == 0 else {
            return []
        }

        return parsePHPVersionsList(output)
    }

    nonisolated func parsePHPVersionsList(_ output: String) -> [PHPVersion] {
        let versionRegex = /(\d+\.\d+(?:\.\d+)?)/
        let pathRegex = #/(/[^\s│|]+)/#

        var versions: [PHPVersion] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("─") || trimmed.hasPrefix("┌") ||
               trimmed.hasPrefix("└") || trimmed.contains("Version") {
                continue
            }

            guard let versionMatch = trimmed.firstMatch(of: versionRegex) else { continue }

            let version = String(versionMatch.1)
            let isDefault = trimmed.lowercased().contains("default") ||
                           trimmed.contains("*") ||
                           trimmed.contains("⭐")

            let path = trimmed.firstMatch(of: pathRegex).map { String($0.1) } ?? ""

            if !versions.contains(where: { $0.version == version }) {
                versions.append(PHPVersion(
                    id: version,
                    version: version,
                    path: path,
                    isDefault: isDefault
                ))
            }
        }

        return versions
    }

    // MARK: - Fetch Proxies

    nonisolated private func fetchProxies(cliPath: String) async -> (list: [SymfonyProxy], running: Bool) {
        let result = await runCommand(cliPath, arguments: ["proxy:status", "--no-ansi"])

        guard let output = result.output, result.exitCode == 0 else {
            return ([], false)
        }

        let list = parseProxiesList(output)
        return (list, true)
    }

    nonisolated func parseProxiesList(_ output: String) -> [SymfonyProxy] {
        let domainRegex = /([a-zA-Z0-9.\-]+\.wip)/
        let pathRegex = #/([~/][^\s|]+)/#

        var proxies: [SymfonyProxy] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("+") || trimmed.hasPrefix("-") ||
               trimmed.contains("Domain") || trimmed.contains("Directory") {
                continue
            }

            for match in trimmed.matches(of: domainRegex) {
                let domain = String(match.1)
                let directory = trimmed.firstMatch(of: pathRegex).map { String($0.1) } ?? ""

                if !proxies.contains(where: { $0.domain == domain }) {
                    proxies.append(SymfonyProxy(
                        id: domain,
                        domain: domain,
                        directory: directory,
                        isActive: true
                    ))
                }
            }
        }

        return proxies
    }

    // MARK: - Known Servers Persistence

    private let knownDirectoriesKey = "KnownServerDirectories"
    private let knownServerRetentionDays: Double = 30
    private let knownServerMaxCount: Int = 10

    /// Stored as [directory: lastSeenTimestamp]
    private var knownServerTimestamps: [String: TimeInterval] {
        get { UserDefaults.standard.dictionary(forKey: knownDirectoriesKey) as? [String: TimeInterval] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: knownDirectoriesKey) }
    }

    /// Merges CLI-fetched servers with recently known directories so that
    /// stopped servers remain visible for up to 30 days after last being seen.
    func mergeWithKnownServers(_ fetched: [SymfonyServer]) -> [SymfonyServer] {
        let fetchedDirs = Set(fetched.map { $0.directory })
        let now = Date().timeIntervalSince1970
        let cutoff = now - knownServerRetentionDays * 86_400

        // Update timestamps for every directory seen right now
        var timestamps = knownServerTimestamps
        for dir in fetchedDirs { timestamps[dir] = now }

        // Drop entries older than the retention window, then keep only the most recent N
        timestamps = timestamps.filter { $0.value >= cutoff }
        if timestamps.count > knownServerMaxCount {
            let sorted = timestamps.sorted { $0.value > $1.value }
            timestamps = Dictionary(uniqueKeysWithValues: sorted.prefix(knownServerMaxCount).map { ($0.key, $0.value) })
        }
        if timestamps != knownServerTimestamps {
            knownServerTimestamps = timestamps
        }

        // Stamp fetched servers with current time and synthesise stopped entries for absent ones
        let stamped = fetched.map { server in
            SymfonyServer(
                id: server.id, directory: server.directory,
                port: server.port, url: server.url, isRunning: server.isRunning,
                pid: server.pid, phpVersion: server.phpVersion, ssl: server.ssl,
                lastSeen: now
            )
        }

        let synthetic: [SymfonyServer] = timestamps.keys
            .filter { !fetchedDirs.contains($0) }
            .map { dir in
                let expanded = (dir as NSString).expandingTildeInPath
                return SymfonyServer(
                    id: expanded,
                    directory: expanded,
                    port: 8000,
                    url: "",
                    isRunning: false,
                    pid: nil,
                    phpVersion: nil,
                    ssl: true,
                    lastSeen: timestamps[dir] ?? 0
                )
            }

        return stamped + synthetic
    }

    // MARK: - Optimistic UI Updates

    /// Immediately flips isRunning for the matching server so the menu reflects the
    /// intended state before the async CLI command completes. The real state is
    /// restored by the refreshServersAsync() call at the end of start/stopServer.
    func optimisticallyMark(directory: String, running: Bool) {
        let expanded = (directory as NSString).expandingTildeInPath
        servers = servers.map { server in
            guard (server.directory as NSString).expandingTildeInPath == expanded else { return server }
            return SymfonyServer(
                id: server.id, directory: server.directory,
                port: server.port, url: server.url, isRunning: running,
                pid: server.pid, phpVersion: server.phpVersion, ssl: server.ssl,
                lastSeen: server.lastSeen
            )
        }
    }

    // MARK: - Server Actions

    func startServer(at directory: String) async {
        guard let cliPath = symfonyCliPath else { return }

        let expandedPath = (directory as NSString).expandingTildeInPath

        let result = await runCommand(cliPath, arguments: ["server:start", "-d", "--dir", expandedPath])

        // Wait for server to actually start
        let started = await waitForServerState(at: expandedPath, expectedRunning: true, timeout: 10.0)

        if result.exitCode != 0 || !started {
            self.lastError = "Failed to start server at \(directory)"
        } else {
            self.lastError = nil
        }

        await refreshServersAsync()
    }

    func stopServer(_ server: SymfonyServer) async {
        guard let cliPath = symfonyCliPath else { return }

        let expandedPath = (server.directory as NSString).expandingTildeInPath

        let result = await runCommand(cliPath, arguments: ["server:stop", "--dir", expandedPath])

        // Wait for server to actually stop
        let stopped = await waitForServerState(at: expandedPath, expectedRunning: false, timeout: 2.0)

        if result.exitCode != 0 || !stopped {
            self.lastError = "Failed to stop server at \(expandedPath)"
        } else {
            self.lastError = nil
        }

        await refreshServersAsync()
    }

    func stopAllServers() async {
        guard let cliPath = symfonyCliPath else { return }

        let runningServers = servers.filter { $0.isRunning }

        for server in runningServers {
            _ = await runCommand(cliPath, arguments: ["server:stop", "--dir=\(server.directory)"])
        }

        try? await Task.sleep(for: .milliseconds(500))

        await refreshServersAsync()
    }

    private func waitForServerState(at directory: String, expectedRunning: Bool, timeout: TimeInterval = 5.0) async -> Bool {
        guard let cliPath = symfonyCliPath else { return false }

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            let result = await runCommand(cliPath, arguments: ["server:list", "--no-ansi"])
            // Only act on successful CLI calls
            guard let output = result.output, result.exitCode == 0 else {
                try? await Task.sleep(for: .milliseconds(300))
                continue
            }
            let servers = parseServerListText(output)
            if let server = servers.first(where: { $0.directory == directory }) {
                if server.isRunning == expectedRunning { return true }
            } else if !expectedRunning {
                // Server absent from a successful CLI call = confirmed stopped
                return true
            }
            try? await Task.sleep(for: .milliseconds(300))
        }
        return false
    }

    // MARK: - Proxy Actions

    func startProxy() async {
        guard let cliPath = symfonyCliPath else { return }
        _ = await runCommand(cliPath, arguments: ["proxy:start"])
        await refreshServersAsync()
    }

    func stopProxy() async {
        guard let cliPath = symfonyCliPath else { return }
        _ = await runCommand(cliPath, arguments: ["proxy:stop"])
        await refreshServersAsync()
    }

    func detachProxyDomain(_ domain: String) async {
        guard let cliPath = symfonyCliPath else { return }
        _ = await runCommand(cliPath, arguments: ["proxy:domain:detach", domain])
        await refreshServersAsync()
    }

    // MARK: - Browser/Finder Actions

    func openInBrowser(_ server: SymfonyServer) {
        if let url = URL(string: server.url) {
            NSWorkspace.shared.open(url)
        }
    }

    func openInFinder(_ server: SymfonyServer) {
        let url = URL(fileURLWithPath: server.directory)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    // MARK: - Command Runner

    nonisolated private func runCommand(_ command: String, arguments: [String] = []) async -> (output: String?, exitCode: Int32) {
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = errorPipe

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:\(NSHomeDirectory())/.symfony5/bin:\(NSHomeDirectory())/.symfony/bin"
        env["TERM"] = "dumb"
        process.environment = env

        guard (try? process.run()) != nil else { return (nil, -1) }

        return await withCheckedContinuation { continuation in
            let completed = OSAllocatedUnfairLock(initialState: false)

            let finish: @Sendable ((String?, Int32)) -> Void = { result in
                let alreadyDone = completed.withLock { state in
                    let was = state; state = true; return was
                }
                guard !alreadyDone else { return }
                continuation.resume(returning: result)
            }

            process.terminationHandler = { p in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                finish((String(data: data, encoding: .utf8), p.terminationStatus))
            }

            Task.detached {
                try? await Task.sleep(for: .seconds(15))
                process.terminate()
                finish((nil, -1))
            }
        }
    }
}
