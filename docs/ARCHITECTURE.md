# Architecture

This document describes the architecture and design decisions of Symfony CLI Menu Bar.

## Overview

Symfony CLI Menu Bar is a native macOS menu bar application that provides a graphical interface for managing Symfony local development servers through the Symfony CLI.

## Technology Stack

- **Language**: Swift 5.9+
- **Framework**: AppKit (native macOS)
- **Build System**: Swift Package Manager
- **Minimum macOS**: 14.0 (Sonoma)
- **Dependencies**: None (uses only system frameworks)

## Architecture Pattern

The app follows a simple **MVC-like pattern** with clear separation of concerns:

```
┌─────────────────────────────────────────┐
│  SymfonyCLIMenuBarApp (SwiftUI App)      │
│  - App entry point                       │
│  - Minimal SwiftUI wrapper               │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  AppDelegate (NSApplicationDelegate)    │
│  - Status bar item management            │
│  - Menu lifecycle                        │
│  - About window                          │
│  - Login items                           │
│  - Release update checks                 │
└──────────────┬──────────────────────────┘
               │
      ┌────────┴────────┐
      ▼                 ▼
┌─────────────┐   ┌─────────────────────┐
│ MenuBuilder │   │ SymfonyServerManager│
│             │   │                     │
│ - Builds    │   │ - Symfony CLI       │
│   NSMenu    │   │   detection         │
│ - Handles   │   │ - Command execution │
│   actions   │   │ - State management  │
│ - UI logic  │   │ - Data parsing      │
└─────────────┘   └─────────────────────┘
```

## Core Components

### 1. SymfonyCLIMenuBarApp

**Responsibility**: App lifecycle and SwiftUI bridge

- Entry point (`@main`)
- Configures AppDelegate
- Minimal - AppKit does the heavy lifting

### 2. AppDelegate

**Responsibility**: macOS integration and menu bar presence

**Key Features**:
- Creates `NSStatusItem` for menu bar icon
- Manages menu lifecycle (open/close/refresh)
- Handles "Start at Login" via `ServiceManagement`
- Shows About window
- Runs the user-initiated release update check
- Coordinates between MenuBuilder and ServerManager

**Design Decision**: Using `NSApplicationDelegate` instead of pure SwiftUI because:
- Menu bar apps require `NSStatusItem` (AppKit)
- Better control over menu bar behavior
- More mature API for status bar apps

### 3. SymfonyServerManager

**Responsibility**: Symfony CLI integration and state management

**Key Features**:
- **CLI Detection**: Searches common paths for `symfony` binary
- **Command Execution**: Runs `symfony` commands and parses output
- **State Management**: Tracks servers, PHP versions, proxies
- **Data Refresh**: Polls every 10 seconds

**Data Flow**:
```
User Action → MenuBuilder → ServerManager → Symfony CLI
                  ↓              ↓              ↓
              Updates Menu  ← Updates State ← Parses Output
```

**State Properties** (`@Published`):
- `servers: [SymfonyServer]` - All detected servers
- `phpVersions: [PHPVersion]` - Installed PHP versions
- `proxies: [SymfonyProxy]` - Active .wip domains
- `isLoading: Bool` - Refresh state
- `lastError: String?` - Last error message

**Threading Model**:
- UI updates: Main thread
- CLI commands: Background queue (`DispatchQueue.global`)
- Parsing: Background thread
- State updates: Published to main thread

### 4. MenuBuilder

**Responsibility**: Menu construction and user interactions

**Key Features**:
- **Dynamic Menu**: Rebuilds on each open
- **Submenus**: Per-server, per-PHP, per-proxy actions
- **Wrapper Classes**: `NSMenuItem.representedObject` needs `NSObject`
- **Visual Design**: Status dots, icons, fonts

### 5. UpdateChecker

**Responsibility**: Lightweight release comparison

- Requests the published cask from `smnandre/homebrew-tap` only when the user chooses **Check for Updates...**
- Parses and compares semantic versions
- Returns release data to `AppDelegate` for presentation
- Does not download, install, or schedule updates
- Accepts a local cask fixture in debug builds for end-to-end alert testing

**Menu Structure**:
```
Symfony CLI 5.12.0                [Header]
├─ PHP                            [Section]
│  ├─ ● 8.4.8 ★                  [Default PHP]
│  ├─ ● 8.3.15                   [Other PHP]
│  └─ ...
├─ PROXIES                        [Section]
│  ├─ ● project.wip              [Active proxy]
│  └─ ...
├─ SERVERS                        [Section]
│  ├─ ● my-app :8000             [Running server]
│  │  ├─ Stop Server
│  │  ├─ Open in Browser
│  │  ├─ Copy URL
│  │  ├─ View Logs
│  │  └─ ...
│  ├─ ○ other-app                [Stopped server]
│  │  ├─ Start Server
│  │  └─ ...
│  └─ ...
├─ Settings
│  ├─ Start at Login
│  └─ Refresh
├─ About
├─ Check for Updates...
└─ Quit
```

## Data Models

### SymfonyServer
```swift
struct SymfonyServer {
    let id: String              // Unique identifier (directory path)
    let name: String            // Project name
    let directory: String       // Full path to project
    let port: Int              // Port number (8000, 8001, etc.)
    let url: String            // https://127.0.0.1:PORT
    let isRunning: Bool        // Server state
    let pid: Int?              // Process ID (if available)
    let phpVersion: String?    // PHP version used
    let ssl: Bool              // SSL enabled
}
```

### PHPVersion
```swift
struct PHPVersion {
    let id: String             // Version string
    let version: String        // 8.4.8
    let path: String           // /usr/local/bin/php
    let isDefault: Bool        // Is this the default?
}
```

### SymfonyProxy
```swift
struct SymfonyProxy {
    let id: String             // Domain name
    let domain: String         // project.wip
    let directory: String      // Project path
    let isActive: Bool         // Proxy active
}
```

## External Integration

### Symfony CLI Commands

| Command | Purpose | Output Format |
|---------|---------|---------------|
| `symfony version` | Get CLI version | Text |
| `symfony server:list` | List all servers | ASCII table |
| `symfony local:php:list` | List PHP versions | ASCII table |
| `symfony proxy:status` | List proxy domains | Text |
| `symfony server:start -d --dir=<path>` | Start server | Text |
| `symfony server:stop --dir=<path>` | Stop server | Text |

**Output Parsing**:
- **Challenge**: No JSON output (yet)
- **Solution**: Regex-based text parsing
- **Risk**: Output format changes break app
- **Mitigation**: Defensive parsing, validation

### System Integration

**NSWorkspace**:
- Open URLs in browser
- Show files in Finder
- Execute `open` commands

**AppleScript**:
- Open Terminal with `cd` command
- Run `symfony server:log` in Terminal
- **Security**: Paths are escaped to prevent injection

**ServiceManagement**:
- Register/unregister login item (macOS 13+)
- Replaces deprecated Launch Services API

**Homebrew cask source**:
- Fetch the cask currently merged in `smnandre/homebrew-tap` for a user-initiated update check
- Show the release page or copy `brew upgrade --cask symfony-cli-menubar`
- No background or automatic network check
- Debug builds may read `SYMFONY_CLI_MENUBAR_CASK_FIXTURE`; release builds always use the public cask

## Threading Model

```
Main Thread                Background Queue
     │                           │
     │ User clicks menu          │
     ├──────────────────────────>│ Run symfony CLI
     │                           │ Parse output
     │                           │
     │<──────────────────────────┤ Update @Published state
     │ UI updates automatically  │
     │                           │
```

**Rules**:
1. All `@Published` updates → Main thread
2. All CLI commands → Background thread
3. All UI updates → Main thread
4. Use `weak self` in async closures

## Error Handling Strategy

**Current State**:
- CLI failures return exit codes
- Parsing errors return empty arrays
- Some errors silently fail

**Improvements Made**:
- `lastError` property for user-visible errors
- Exit code checking in start/stop operations
- Escape strings in AppleScript

**Future Improvements**:
- User notifications for errors
- Retry logic for transient failures
- Better error messages

## Security Considerations

### Input Validation
- **Paths**: Always escape single quotes in AppleScript
- **CLI Output**: Defensive parsing with regex
- **User Input**: Minimal (only menu selections)

### Permissions
- **Terminal**: Requires Automation permission
- **File System**: Read-only access to project directories
- **Network**: User-initiated request to the published Homebrew cask on GitHub

### Code Signing
- Required for distribution outside App Store
- Notarization required for macOS 10.15+
- Release bundle identifier: `dev.smnandre.symfony-cli-menubar`
- Release workflow verifies Developer ID signing and Apple notarization before publication

## Performance

### Refresh Strategy
- **Interval**: 10 seconds (configurable)
- **Trigger**: Also refreshes on menu open
- **Optimization**: Parallel fetching of servers, PHP, proxies

### Menu Building
- **Strategy**: Rebuild on each open
- **Cost**: Minimal (< 100ms for typical usage)
- **Optimization**: Limit visible items (e.g., show 2 proxies, expand for more)

### Memory
- **Footprint**: ~10-15 MB (typical menu bar app)
- **Leaks**: Prevented by `weak self` in closures

## Build System

### Swift Package Manager
```
Package.swift
├─ Executable target: SymfonyCLIMenuBar
└─ Test target: SymfonyCLIMenuBarTests
```

**Why SPM?**
- No Xcode project to maintain
- Simpler for contributors
- Standard Swift tooling
- Fast builds

### Packaging Script (`scripts/package.sh`)
1. Validate the stable version supplied by the caller or release tag
2. Build with Swift Package Manager for the requested architecture
3. Create the `.app` bundle and write the version to both bundle version keys
4. Copy the executable, metadata, resources, and icon
5. Sign with Developer ID in CI or ad hoc locally

### CI/CD (GitHub Actions)
1. **build.yml**: On every push/PR
   - Build
   - Run tests
   - Upload artifact

2. **release.yml**: On version tags
   - Build
   - Generate icon
   - Sign and notarize the ARM-only DMG
   - Publish the GitHub Release
   - Open the Homebrew cask update pull request

## Design Decisions

### Why AppKit over SwiftUI?
- Menu bar apps are AppKit-native
- `NSStatusItem` is mature and well-documented
- SwiftUI menu bar support is limited
- More control over menu behavior

### Why No Dependencies?
- Simpler distribution
- Faster builds
- Smaller third-party supply-chain surface
- Standard library has everything we need

### Why Poll Every 10 Seconds?
- Balance between responsiveness and CPU usage
- Symfony CLI doesn't provide event notifications
- Menu also refreshes on open (instant feedback)

### Why Not Bundle Symfony CLI?
- Symfony CLI is updated frequently
- Users should manage their own CLI version
- Reduces app size
- Licensing simplicity

## Future Considerations

### Potential Improvements
1. **JSON Output**: Request Symfony CLI team to add `--json` flag
2. **Event-Based Updates**: Watch filesystem for changes
3. **Preferences Window**: Replace settings submenu
4. **Notifications**: Alert on server start/stop
5. **Custom Ports**: UI to specify preferred ports
6. **Log Viewer**: In-app log display instead of Terminal

### Technical Debt
1. Text parsing is fragile (needs JSON)
2. Hardcoded sleep durations
3. No retry logic for transient failures
4. Version management across multiple files

## Testing Strategy

### Unit Tests
- Model equality
- CLI detection
- (Future) Output parsing with fixtures

### Integration Tests
- Requires Symfony CLI installed
- Tests actual CLI commands
- Runs on CI

### Manual Testing
- Menu interactions
- Server start/stop
- PHP version switching
- About window
- Login items
- Update check result and Homebrew command

## Resources

- [Symfony CLI Documentation](https://symfony.com/doc/current/setup/symfony_server.html)
- [AppKit Documentation](https://developer.apple.com/documentation/appkit)
- [Swift Package Manager](https://swift.org/package-manager/)
- [ServiceManagement Framework](https://developer.apple.com/documentation/servicemanagement)
