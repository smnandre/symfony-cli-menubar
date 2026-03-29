// Symfony CLI Menu Bar
// Copyright © 2026 Simon André <smn.andre@gmail.com>
// Open source software — MIT License
//
// "Symfony" is a registered trademark of Symfony SAS, used with kind permission.
// This app is not affiliated with or endorsed by Symfony SAS or SensioLabs.

import AppKit

// MARK: - Custom Heart Button

class HeartButton: NSButton {
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        contentTintColor = .systemPink
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        contentTintColor = .secondaryLabelColor
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        for area in trackingAreas {
            removeTrackingArea(area)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
}

// MARK: - Generic payload wrapper for menu representedObject (structs don't work)

final class MenuItemPayload<T>: NSObject {
    let value: T
    init(_ value: T) { self.value = value }
}

/// Builds the native NSMenu for the status bar app
@MainActor
class MenuBuilder: NSObject, NSMenuDelegate {
    private let serverManager: SymfonyServerManager
    private weak var appDelegate: AppDelegate?

    // Constants for consistent formatting
    private let labelFont = NSFont.systemFont(ofSize: 13)
    private let monoFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    private let smallMonoFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private let sectionFont = NSFont.systemFont(ofSize: 11, weight: .semibold)

    // Menu minimum width
    private let menuMinWidth: CGFloat = 300

    init(serverManager: SymfonyServerManager, appDelegate: AppDelegate) {
        self.serverManager = serverManager
        self.appDelegate = appDelegate
        super.init()
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        menu.minimumWidth = menuMinWidth

        addHeader(to: menu)
        menu.addItem(NSMenuItem.separator())

        let showPHP = UserDefaults.standard.object(forKey: Prefs.showPHPVersions) as? Bool ?? true
        let showProxies = UserDefaults.standard.object(forKey: Prefs.showProxies) as? Bool ?? true
        let showServers = UserDefaults.standard.object(forKey: Prefs.showServers) as? Bool ?? true

        if showPHP {
            addPHPSection(to: menu)
            menu.addItem(NSMenuItem.separator())
        }

        if showProxies {
            addProxiesSection(to: menu, proxies: serverManager.proxies)
            menu.addItem(NSMenuItem.separator())
        }

        if showServers {
            addServersSection(to: menu)
            menu.addItem(NSMenuItem.separator())
        }

        // Settings
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(showPreferences), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsItem)

        // About
        let aboutItem = NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "i")
        aboutItem.target = self
        aboutItem.keyEquivalentModifierMask = [.command]
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        Task {
            await serverManager.refreshServersAsync()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        appDelegate?.rebuildMenu()
    }

    // MARK: - Header with custom view

    private func addHeader(to menu: NSMenu) {
        let headerItem = NSMenuItem()

        let headerView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))

        // Title
        let titleLabel = NSTextField(labelWithString: AppInfo.name)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 12, y: 4, width: 240, height: 20)
        headerView.addSubview(titleLabel)

        // Heart button
        let heartButton = HeartButton(frame: NSRect(x: 268, y: 4, width: 20, height: 20))
        heartButton.image = NSImage(systemSymbolName: "heart", accessibilityDescription: "Support")
        heartButton.bezelStyle = .inline
        heartButton.isBordered = false
        heartButton.contentTintColor = .secondaryLabelColor
        heartButton.action = #selector(openGitHub)
        heartButton.target = self
        headerView.addSubview(heartButton)

        headerItem.view = headerView
        menu.addItem(headerItem)
    }

    // MARK: - PHP Section

    private func addPHPSection(to menu: NSMenu) {
        menu.addItem(createSectionHeader("PHP"))

        let phpVersions = serverManager.phpVersions
        if phpVersions.isEmpty {
            menu.addItem(createDisabledItem("No PHP versions detected"))
        } else {
            let sortedVersions = phpVersions.sorted { v1, v2 in
                if v1.isDefault { return true }
                if v2.isDefault { return false }
                return v1.version.compare(v2.version, options: .numeric) == .orderedDescending
            }

            for phpVersion in sortedVersions {
                menu.addItem(createPHPMenuItem(phpVersion))
            }
        }
    }

    private func createPHPMenuItem(_ php: PHPVersion) -> NSMenuItem {
        let item = NSMenuItem()

        let title = NSMutableAttributedString()
        let dotColor = php.isDefault ? NSColor.systemGreen : NSColor.systemGray
        title.append(createStatusDot(color: dotColor))
        title.append(NSAttributedString(
            string: php.version,
            attributes: [.font: monoFont, .foregroundColor: NSColor.labelColor]
        ))

        if php.isDefault {
            title.append(NSAttributedString(
                string: "  ★",
                attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.systemYellow]
            ))
        }

        item.attributedTitle = title

        // Submenu
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        submenu.addItem(createDisabledItem("PHP \(php.version)"))
        submenu.addItem(NSMenuItem.separator())

        if !php.path.isEmpty {
            submenu.addItem(createPathItem(php.path))

            let copyPathItem = NSMenuItem(title: "Copy Path", action: #selector(copyPHPPath(_:)), keyEquivalent: "")
            copyPathItem.target = self
            copyPathItem.representedObject = MenuItemPayload(php)
            copyPathItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy Path")
            submenu.addItem(copyPathItem)

            let showFinderItem = NSMenuItem(title: "Show in Finder", action: #selector(showPHPInFinder(_:)), keyEquivalent: "")
            showFinderItem.target = self
            showFinderItem.representedObject = MenuItemPayload(php)
            showFinderItem.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Show in Finder")
            submenu.addItem(showFinderItem)
        }

        submenu.addItem(NSMenuItem.separator())

        if !php.isDefault {
            let setDefaultItem = NSMenuItem(title: "Set as Default", action: #selector(setPHPAsDefault(_:)), keyEquivalent: "")
            setDefaultItem.target = self
            setDefaultItem.representedObject = MenuItemPayload(php)
            setDefaultItem.image = NSImage(systemSymbolName: "star", accessibilityDescription: "Set as Default")
            submenu.addItem(setDefaultItem)
        } else {
            let currentDefaultItem = createDisabledItem("✓ Current Default")
            currentDefaultItem.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Current Default")
            submenu.addItem(currentDefaultItem)
        }

        item.submenu = submenu
        return item
    }

    // MARK: - Proxies Section

    private func addProxiesSection(to menu: NSMenu, proxies: [SymfonyProxy]) {
        menu.addItem(createSectionHeader("PROXIES"))

        if serverManager.isProxyRunning {
            let maxP = UserDefaults.standard.object(forKey: Prefs.maxProxies) as? Double ?? 2.0
            let maxProxies = Int(maxP)
            
            let visibleProxies = Array(proxies.prefix(maxProxies))
            for proxy in visibleProxies {
                menu.addItem(createProxyMenuItem(proxy))
            }

            if proxies.count > maxProxies {
                let manageItem = NSMenuItem()
                manageItem.attributedTitle = NSAttributedString(
                    string: "Manage proxies (\(proxies.count))",
                    attributes: [.font: labelFont, .foregroundColor: NSColor.secondaryLabelColor]
                )

                let submenu = NSMenu()
                for proxy in proxies {
                    submenu.addItem(createProxyMenuItem(proxy))
                }

                if !proxies.isEmpty {
                    submenu.addItem(NSMenuItem.separator())
                }

                let stopItem = NSMenuItem(title: "Stop Proxy", action: #selector(stopProxyAction), keyEquivalent: "")
                stopItem.target = self
                submenu.addItem(stopItem)

                manageItem.submenu = submenu
                menu.addItem(manageItem)
            } else {
                let stopItem = NSMenuItem(title: "Stop Proxy", action: #selector(stopProxyAction), keyEquivalent: "")
                stopItem.target = self
                menu.addItem(stopItem)
            }
        } else {
            menu.addItem(createDisabledItem("Proxy is not running"))

            let startItem = NSMenuItem(title: "Start Proxy", action: #selector(startProxyAction), keyEquivalent: "")
            startItem.target = self
            menu.addItem(startItem)
        }
    }

    private func createProxyMenuItem(_ proxy: SymfonyProxy) -> NSMenuItem {
        let item = NSMenuItem()

        let title = NSMutableAttributedString()
        let dotColor = proxy.isActive ? NSColor.systemGreen : NSColor.systemGray
        title.append(createStatusDot(color: dotColor))
        title.append(NSAttributedString(
            string: proxy.domain,
            attributes: [.font: labelFont, .foregroundColor: NSColor.labelColor]
        ))

        item.attributedTitle = title

        // Submenu
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        submenu.addItem(createDisabledItem(proxy.domain))
        submenu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: "Open in Browser", action: #selector(openProxyInBrowser(_:)), keyEquivalent: "")
        openItem.target = self
        openItem.representedObject = MenuItemPayload(proxy)
        openItem.image = NSImage(systemSymbolName: "safari", accessibilityDescription: "Open in Browser")
        submenu.addItem(openItem)

        let copyUrlItem = NSMenuItem(title: "Copy URL", action: #selector(copyProxyURL(_:)), keyEquivalent: "")
        copyUrlItem.target = self
        copyUrlItem.representedObject = MenuItemPayload(proxy)
        copyUrlItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy URL")
        submenu.addItem(copyUrlItem)

        if !proxy.directory.isEmpty {
            submenu.addItem(NSMenuItem.separator())
            submenu.addItem(createPathItem(proxy.directory))

            let finderItem = NSMenuItem(title: "Show in Finder", action: #selector(showProxyInFinder(_:)), keyEquivalent: "")
            finderItem.target = self
            finderItem.representedObject = MenuItemPayload(proxy)
            finderItem.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Show in Finder")
            submenu.addItem(finderItem)
        }

        submenu.addItem(NSMenuItem.separator())

        let detachItem = NSMenuItem(title: "Detach Domain", action: #selector(detachProxyDomain(_:)), keyEquivalent: "")
        detachItem.target = self
        detachItem.representedObject = MenuItemPayload(proxy)
        detachItem.image = NSImage(systemSymbolName: "minus.circle", accessibilityDescription: "Detach Domain")
        submenu.addItem(detachItem)

        item.submenu = submenu
        return item
    }

    // MARK: - Servers Section

    private func addServersSection(to menu: NSMenu) {
        menu.addItem(createSectionHeader("SERVERS"))

        let servers = serverManager.servers
        if servers.isEmpty {
            menu.addItem(createDisabledItem("No servers registered"))
            return
        }

        let sortedServers = servers.sorted { s1, s2 in
            s1.lastSeen > s2.lastSeen
        }

        let maxStopped = Int(UserDefaults.standard.object(forKey: Prefs.maxStoppedServers) as? Double ?? 3.0)

        let runningServers = sortedServers.filter {  $0.isRunning }
        let stoppedServers = sortedServers.filter { !$0.isRunning }

        for server in runningServers {
            menu.addItem(createServerMenuItem(server))
        }

        let displayStopped = stoppedServers.count > maxStopped ? Array(stoppedServers.prefix(maxStopped)) : stoppedServers
        for server in displayStopped {
            menu.addItem(createServerMenuItem(server))
        }

        if stoppedServers.count > maxStopped {
            let manageItem = NSMenuItem()
            manageItem.attributedTitle = NSAttributedString(
                string: "Manage servers (\(servers.count))",
                attributes: [.font: labelFont, .foregroundColor: NSColor.secondaryLabelColor]
            )

            let submenu = NSMenu()
            for server in sortedServers {
                submenu.addItem(createServerMenuItem(server))
            }

            if runningServers.count > 0 {
                submenu.addItem(NSMenuItem.separator())
                let stopAllItem = NSMenuItem(title: "Stop All Servers", action: #selector(stopAllServersAction), keyEquivalent: "")
                stopAllItem.target = self
                submenu.addItem(stopAllItem)
            }

            manageItem.submenu = submenu
            menu.addItem(manageItem)
        } else if runningServers.count > 0 {
            let stopAllItem = NSMenuItem(title: "Stop All Servers", action: #selector(stopAllServersAction), keyEquivalent: "")
            stopAllItem.target = self
            menu.addItem(stopAllItem)
        }
    }

    private func createServerMenuItem(_ server: SymfonyServer) -> NSMenuItem {
        let item = NSMenuItem()

        let title = NSMutableAttributedString()
        let dotColor = server.isRunning ? NSColor.systemGreen : NSColor.systemGray.withAlphaComponent(0.5)
        title.append(createStatusDot(color: dotColor))
        title.append(NSAttributedString(
            string: server.displayName,
            attributes: [.font: labelFont, .foregroundColor: NSColor.labelColor]
        ))

        if server.isRunning {
            title.append(NSAttributedString(
                string: "\t:\(server.port)",
                attributes: [.font: smallMonoFont, .foregroundColor: NSColor.secondaryLabelColor]
            ))
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.tabStops = [NSTextTab(textAlignment: .right, location: 222)]
            title.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: title.length))
        }

        item.attributedTitle = title

        // Submenu
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        // Header
        submenu.addItem(createDisabledItem(server.displayName))

        // Status
        let statusItem = NSMenuItem()
        let statusText = server.isRunning ? "● Running on port \(server.port)" : "○ Stopped"
        let statusColor = server.isRunning ? NSColor.systemGreen : NSColor.systemGray
        statusItem.attributedTitle = NSAttributedString(
            string: statusText,
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: statusColor]
        )
        statusItem.isEnabled = false
        submenu.addItem(statusItem)

        submenu.addItem(NSMenuItem.separator())

        // Start/Stop - these are the key actions
        if server.isRunning {
            let stopItem = NSMenuItem(title: "Stop Server", action: #selector(stopServerAction(_:)), keyEquivalent: "")
            stopItem.target = self
            stopItem.representedObject = MenuItemPayload(server)
            stopItem.image = NSImage(systemSymbolName: "stop.circle", accessibilityDescription: "Stop Server")
            submenu.addItem(stopItem)

            let openItem = NSMenuItem(title: "Open in Browser", action: #selector(openServerInBrowser(_:)), keyEquivalent: "")
            openItem.target = self
            openItem.representedObject = MenuItemPayload(server)
            openItem.image = NSImage(systemSymbolName: "safari", accessibilityDescription: "Open in Browser")
            submenu.addItem(openItem)

            let copyUrlItem = NSMenuItem(title: "Copy URL", action: #selector(copyServerURL(_:)), keyEquivalent: "")
            copyUrlItem.target = self
            copyUrlItem.representedObject = MenuItemPayload(server)
            copyUrlItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy URL")
            submenu.addItem(copyUrlItem)

            submenu.addItem(NSMenuItem.separator())

            let logsItem = NSMenuItem(title: "View Logs", action: #selector(viewServerLogs(_:)), keyEquivalent: "")
            logsItem.target = self
            logsItem.representedObject = MenuItemPayload(server)
            logsItem.image = NSImage(systemSymbolName: "list.bullet.rectangle", accessibilityDescription: "View Logs")
            submenu.addItem(logsItem)
        } else {
            let startItem = NSMenuItem(title: "Start Server", action: #selector(startServerAction(_:)), keyEquivalent: "")
            startItem.target = self
            startItem.representedObject = MenuItemPayload(server)
            startItem.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: "Start Server")
            submenu.addItem(startItem)
        }

        submenu.addItem(NSMenuItem.separator())

        // Path
        submenu.addItem(createPathItem(server.directory))

        let copyPathItem = NSMenuItem(title: "Copy Path", action: #selector(copyServerPath(_:)), keyEquivalent: "")
        copyPathItem.target = self
        copyPathItem.representedObject = MenuItemPayload(server)
        copyPathItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy Path")
        submenu.addItem(copyPathItem)

        let finderItem = NSMenuItem(title: "Show in Finder", action: #selector(showServerInFinder(_:)), keyEquivalent: "")
        finderItem.target = self
        finderItem.representedObject = MenuItemPayload(server)
        finderItem.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Show in Finder")
        submenu.addItem(finderItem)

        let terminalItem = NSMenuItem(title: "Open in Terminal", action: #selector(openServerInTerminal(_:)), keyEquivalent: "")
        terminalItem.target = self
        terminalItem.representedObject = MenuItemPayload(server)
        terminalItem.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Open in Terminal")
        submenu.addItem(terminalItem)

        item.submenu = submenu
        return item
    }

    // MARK: - Helpers

    private func createStatusDot(color: NSColor) -> NSAttributedString {
        let dot = NSMutableAttributedString(
            string: "●",
            attributes: [
                .font: NSFont.systemFont(ofSize: 8),
                .foregroundColor: color,
                .baselineOffset: 2.5
            ]
        )
        dot.append(NSAttributedString(string: "  ", attributes: [.font: labelFont]))
        return dot
    }

    private func createPathItem(_ path: String) -> NSMenuItem {
        let item = NSMenuItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: menuMinWidth, height: 18))
        let label = NSTextField(labelWithString: path)
        label.font = smallMonoFont
        label.textColor = .tertiaryLabelColor
        label.frame = NSRect(x: 14, y: 1, width: menuMinWidth - 28, height: 16)
        view.addSubview(label)
        item.view = view
        return item
    }

    private func createSectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: sectionFont, .foregroundColor: NSColor.labelColor.withAlphaComponent(0.65), .kern: 0.8]
        )
        item.isEnabled = false
        return item
    }

    private func createDisabledItem(_ text: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.attributedTitle = NSAttributedString(
            string: text,
            attributes: [.font: labelFont, .foregroundColor: NSColor.tertiaryLabelColor]
        )
        item.isEnabled = false
        return item
    }

    // MARK: - Actions

    @objc func openGitHub() {
        if let url = URL(string: AppInfo.githubURL) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func copyPHPPath(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuItemPayload<PHPVersion> else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload.value.path, forType: .string)
    }

    @objc func showPHPInFinder(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuItemPayload<PHPVersion> else { return }
        let url = URL(fileURLWithPath: payload.value.path)
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }

    @objc func setPHPAsDefault(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuItemPayload<PHPVersion> else { return }

        let phpVersion = payload.value.version
        let phpVersionFile = "\(NSHomeDirectory())/.php-version"

        do {
            try phpVersion.write(toFile: phpVersionFile, atomically: true, encoding: .utf8)
            appDelegate?.rebuildMenuAsync()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not set PHP \(phpVersion) as default"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc func openProxyInBrowser(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuItemPayload<SymfonyProxy> else { return }
        if let url = URL(string: "https://\(payload.value.domain)") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func copyProxyURL(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuItemPayload<SymfonyProxy> else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("https://\(payload.value.domain)", forType: .string)
    }

    @objc func showProxyInFinder(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuItemPayload<SymfonyProxy> else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: payload.value.directory)
    }

    @objc func detachProxyDomain(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuItemPayload<SymfonyProxy> else { return }
        Task {
            await serverManager.detachProxyDomain(payload.value.domain)
            appDelegate?.rebuildMenu()
        }
    }

    // MARK: - Proxy Actions

    @objc func startProxyAction() {
        Task {
            await serverManager.startProxy()
            appDelegate?.rebuildMenu()
        }
    }

    @objc func stopProxyAction() {
        Task {
            await serverManager.stopProxy()
            appDelegate?.rebuildMenu()
        }
    }

    @objc func stopAllServersAction() {
        Task {
            await serverManager.stopAllServers()
            appDelegate?.rebuildMenu()
        }
    }

    // MARK: - Server Actions

    @objc func startServerAction(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuItemPayload<SymfonyServer> else { return }

        // Optimistic update: show the server as running immediately
        serverManager.optimisticallyMark(directory: payload.value.directory, running: true)
        appDelegate?.rebuildMenu()

        Task {
            await serverManager.startServer(at: payload.value.directory)
            appDelegate?.rebuildMenu()
        }
    }

    @objc func stopServerAction(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuItemPayload<SymfonyServer> else { return }

        // Optimistic update: show the server as stopped immediately
        serverManager.optimisticallyMark(directory: payload.value.directory, running: false)
        appDelegate?.rebuildMenu()

        Task {
            await serverManager.stopServer(payload.value)
            appDelegate?.rebuildMenu()
        }
    }

    @objc func openServerInBrowser(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuItemPayload<SymfonyServer> else { return }
        if let url = URL(string: payload.value.url) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func copyServerURL(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuItemPayload<SymfonyServer> else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload.value.url, forType: .string)
    }

    @objc func copyServerPath(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuItemPayload<SymfonyServer> else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload.value.directory, forType: .string)
    }

    @objc func showServerInFinder(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuItemPayload<SymfonyServer> else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: payload.value.directory)
    }

    @objc func openServerInTerminal(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuItemPayload<SymfonyServer> else { return }
        openTerminalAtPath(payload.value.directory)
    }

    @objc func viewServerLogs(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuItemPayload<SymfonyServer>,
              let cliPath = serverManager.symfonyCliPath else { return }

        let escapedCliPath = cliPath.replacingOccurrences(of: "'", with: "'\\''")
        let escapedDir = payload.value.directory.replacingOccurrences(of: "'", with: "'\\''")

        runAppleScript("""
            tell application "Terminal"
                activate
                do script "'\(escapedCliPath)' server:log --dir='\(escapedDir)'"
            end tell
            """)
    }

    @objc func toggleStartAtLogin() {
        appDelegate?.toggleStartAtLogin()
    }

    @objc func showPreferences() {
        appDelegate?.showPreferencesWindow()
    }

    @objc func showAbout() {
        appDelegate?.showAboutWindow()
    }

    @objc func refresh() {
        serverManager.refreshServers()
        appDelegate?.rebuildMenu()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    private func openTerminalAtPath(_ path: String) {
        let escapedPath = path.replacingOccurrences(of: "'", with: "'\\''")

        runAppleScript("""
            tell application "Terminal"
                activate
                do script "cd '\(escapedPath)'"
            end tell
            """)
    }

    private func runAppleScript(_ source: String) {
        guard let script = NSAppleScript(source: source) else { return }
        var errorDict: NSDictionary?
        script.executeAndReturnError(&errorDict)
        if let errorDict {
            let message = errorDict[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error."
            let alert = NSAlert()
            alert.messageText = "Script Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
