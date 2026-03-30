// Symfony CLI Menu Bar
// Copyright © 2026 Simon André <smn.andre@gmail.com>
// Open source software — MIT License
//
// "Symfony" is a registered trademark of Symfony SAS, used with kind permission.
// This app is not affiliated with or endorsed by Symfony SAS or SensioLabs.


import SwiftUI
import AppKit
import ServiceManagement
import OSLog
import Sparkle

// MARK: - App Constants

enum AppInfo {
    static let name = "Symfony CLI MenuBar"
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    static let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    static let author = "Simon André"
    static let email = "smn.andre@gmail.com"
    static let githubURL = "https://github.com/smnandre/symfony-cli-menubar"
    static let twitterURL = "https://x.com/simonandre"
    static let websiteURL = "https://smnandre.dev"
    static let copyright = "© 2026 Simon André. All rights reserved."
    static let symfonyCliURL = "https://github.com/symfony-cli/symfony-cli"
}

enum Prefs {
    static let refreshInterval   = "RefreshInterval"
    static let maxStoppedServers = "MaxStoppedServersToShow"
    static let maxProxies        = "MaxProxiesToShow"
    static let showPHPVersions   = "ShowPHPVersions"
    static let showProxies       = "ShowProxies"
    static let showServers       = "ShowServers"

    static let didChange = Notification.Name("com.simonandre.SymfonyCLIMenuBar.preferencesChanged")
}

private let logger = Logger(subsystem: "com.simonandre.SymfonyCLIMenuBar", category: "App")

@main
struct SymfonyCLIMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var serverManager: SymfonyServerManager!
    var menuBuilder: MenuBuilder!
    var timer: Timer?
    var aboutWindow: NSWindow?
    var preferencesWindow: NSWindow?
    private var updaterController: SPUStandardUpdaterController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("SymfonyCLIMenuBar starting...")

        NSApp.setActivationPolicy(.accessory)

        let sparkleKey = (Bundle.main.infoDictionary?["SUPublicEDKey"] as? String) ?? ""
        if !sparkleKey.isEmpty {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
            )
            try? updaterController.updater.start()
        }

        serverManager = SymfonyServerManager()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            if let iconImage = NSImage(named: "symfony-cli-menubar") {
                iconImage.isTemplate = true
                iconImage.size = NSSize(width: 18, height: 18)
                button.image = iconImage
            } else {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)
                let image = NSImage(systemSymbolName: "s.circle.fill", accessibilityDescription: "Symfony CLI Menu Bar")
                image?.isTemplate = true
                button.image = image?.withSymbolConfiguration(config)
            }
        }

        menuBuilder = MenuBuilder(serverManager: serverManager, appDelegate: self)
        rebuildMenu()
        startMonitoring()

        logger.info("SymfonyCLIMenuBar ready!")
    }

    func startMonitoring() {
        Task {
            await serverManager.setupAsync()
            rebuildMenu()
            if serverManager.symfonyCliPath == nil {
                showSymfonyCliNotFoundAlert()
            }
        }

        scheduleTimer()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange),
            name: Prefs.didChange,
            object: nil
        )
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let stored = UserDefaults.standard.double(forKey: Prefs.refreshInterval)
        let interval = stored > 0 ? stored : 10.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.serverManager.refreshServersAsync()
                self.rebuildMenu()
            }
        }
    }

    @objc private func preferencesDidChange() {
        let stored = UserDefaults.standard.double(forKey: Prefs.refreshInterval)
        let interval = stored > 0 ? stored : 10.0
        if abs((timer?.timeInterval ?? 0) - interval) > 0.1 {
            scheduleTimer()
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        statusItem.menu = menuBuilder.buildMenu()
    }

    func rebuildMenuAsync() {
        Task {
            await serverManager.refreshServersAsync()
            rebuildMenu()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Symfony CLI Not Found

    private func showSymfonyCliNotFoundAlert() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Symfony CLI Not Found"
        alert.informativeText = "The Symfony CLI could not be found on your system.\n\nInstall it to use \(AppInfo.name)."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Install Symfony CLI")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: AppInfo.symfonyCliURL) {
                NSWorkspace.shared.open(url)
            }
        } else {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Start at Login

    func isStartAtLoginEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    func toggleStartAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Start at Login"
            alert.informativeText = "Could not change login item status: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        rebuildMenu()
    }

    // MARK: - Update

    @objc func checkForUpdates(_ sender: Any?) {
        updaterController?.checkForUpdates(sender)
    }

    // MARK: - About Window

    func showAboutWindow() {
        if aboutWindow == nil {
            aboutWindow = createAboutWindow()
        }

        aboutWindow?.center()
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Preferences Window

    func showPreferencesWindow() {
        if preferencesWindow == nil {
            preferencesWindow = createPreferencesWindow()
        }

        preferencesWindow?.center()
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createPreferencesWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: PreferencesView(serverManager: serverManager))
        return window
    }

    private func createAboutWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About \(AppInfo.name)"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: AboutView())
        return window
    }
}
