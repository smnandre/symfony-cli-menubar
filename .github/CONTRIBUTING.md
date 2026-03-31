# Contributing to Symfony CLI Menu Bar

Thank you for your interest in contributing to Symfony CLI Menu Bar! This document provides guidelines and instructions for contributing.

## Code of Conduct

Be respectful, constructive, and professional in all interactions.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/smnandre/symfony-cli-menubar/issues)
2. If not, create a new issue with:
   - Clear, descriptive title
   - Steps to reproduce
   - Expected vs actual behavior
   - macOS version and Symfony CLI version
   - Screenshots if applicable

### Suggesting Features

1. Check existing issues for similar suggestions
2. Create a new issue with `[Feature Request]` prefix
3. Describe the feature and its use case
4. Explain why it would benefit users

### Pull Requests

1. **Fork the repository** and create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following the code style:
   - Use Swift 5.9+ features appropriately
   - Follow existing naming conventions
   - Add comments for complex logic
   - Use MARK: comments to organize code

3. **Test your changes**:
   ```bash
   swift build
   swift test
   ./scripts/package.sh
   open SymfonyCLIMenuBar.app
   ```

4. **Commit with clear messages**:
   ```bash
   git commit -m "Add feature: description of what changed"
   ```
   - Use present tense ("Add feature" not "Added feature")
   - Reference issues: "Fixes #123"

5. **Push and create PR**:
   ```bash
   git push origin feature/your-feature-name
   ```
   - Fill out the PR template
   - Link related issues
   - Add screenshots for UI changes

## Development Setup

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ with Swift 5.9+
- [Symfony CLI](https://symfony.com/download) for testing
- Homebrew (for icon generation)

### Building from Source

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/symfony-cli-menubar.git
cd symfony-cli-menubar

# Build
swift build -c release
./scripts/package.sh

# Run
open SymfonyCLIMenuBar.app
```

### Project Structure

```
SymfonyCLIMenuBar/
├── Sources/
│   ├── SymfonyCLIMenuBarApp.swift   # App entry, AppDelegate, About window
│   ├── SymfonyServerManager.swift  # Symfony CLI integration, state management
│   └── MenuBuilder.swift           # Menu construction, actions, UI
├── scripts/
│   ├── bump-version.sh             # Optional local version bump preview
│   ├── package.sh                  # Build, bundle, and sign the .app
│   ├── embed_sparkle.sh            # Sparkle framework embedding & signing
│   ├── create-dmg.sh              # DMG packaging for distribution
│   └── update_appcast.sh          # Sparkle appcast feed update
├── .github/workflows/
│   ├── build.yml                  # CI for PRs and commits
│   └── release.yml                # Release automation on tags
└── Tests/                         # Unit tests (add tests here!)
```

### Adding Tests

We need more tests! Please add tests for:

```swift
// Tests/SymfonyServerManagerTests.swift
import XCTest
@testable import SymfonyCLIMenuBar

final class SymfonyServerManagerTests: XCTestCase {
    func testParseServerList() {
        // Add parsing tests here
    }
}
```

### Code Style Guidelines

1. **Use Swift standard style**:
   - 4 spaces for indentation
   - Open braces on same line
   - Type inference where clear

2. **Naming**:
   - Classes: `SymfonyServerManager`
   - Functions: `refreshServers()`, `startServer(at:)`
   - Properties: `isRunning`, `phpVersion`
   - Constants: `APP_NAME`, `BUILD_DIR`

3. **Error Handling**:
   - Use Result<T, Error> for fallible operations
   - Provide meaningful error messages
   - Don't silently fail

4. **Threading**:
   - UI updates on main thread
   - Long operations on background queues
   - Use weak self in closures

5. **Comments**:
   - Use MARK: for section organization
   - Comment "why" not "what"
   - Document public APIs

### Icon Generation

```bash
brew install librsvg
./assets/generate_icns.sh
```

## Questions?

- Open a [Discussion](https://github.com/smnandre/symfony-cli-menubar/discussions)
- Reach out on [Twitter](https://twitter.com/smnandre)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
