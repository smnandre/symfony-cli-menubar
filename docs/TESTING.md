# Testing Guide

## Overview

Symfony CLI Menu Bar includes unit tests to ensure code quality and reliability. Tests focus on:
- Path escaping (security)
- Version parsing (regex patterns)
- Domain validation
- File path handling

## Running Tests

### Prerequisites

- **Full Xcode** (not just Command Line Tools)
- macOS 13.0+ 
- Swift 5.9+

### Run Tests

```bash
# Run all tests
swift test

# Run with verbose output
swift test --verbose

# Run specific test
swift test --filter SymfonyCLIMenuBarTests.testPathEscaping_SingleQuote
```

### In Xcode

```bash
# Generate Xcode project (if needed)
swift package generate-xcodeproj

# Open and run tests
open SymfonyCLIMenuBar.xcodeproj
# Press Cmd+U to run tests
```

## Test Structure

```
Tests/
└── SymfonyCLIMenuBarTests/
    └── SymfonyServerManagerTests.swift
```

## Current Tests

### Security Tests
- `testPathEscaping_SingleQuote` - Escape single quotes in AppleScript paths
- `testPathEscaping_MultipleQuotes` - Handle multiple quotes
- `testPathEscaping_NoQuotes` - Safe paths remain unchanged

### Parsing Tests
- `testVersionParsing_ValidFormat` - Valid PHP version formats (8.4.8)
- `testVersionParsing_InvalidFormat` - Reject invalid formats
- `testProxyDomain_ValidWipDomain` - Match .wip domains
- `testProxyDomain_InvalidDomain` - Reject invalid domains
- `testServerState_RunningDetection` - Detect running vs stopped servers

### File Path Tests  
- `testFilePath_TildeExpansion` - Expand ~ to home directory
- `testFilePath_LastComponent` - Extract project name from path

## Adding Tests

### 1. Create Test Function

```swift
func testMyFeature() {
    // Arrange
    let input = "test"
    
    // Act
    let result = processInput(input)
    
    // Assert
    XCTAssertEqual(result, "expected")
}
```

### 2. Test Naming Convention

- Start with `test`
- Describe what's being tested
- Include scenario: `testServerParsing_WithMultipleServers`

### 3. Use XCTest Assertions

```swift
XCTAssertTrue(condition)
XCTAssertFalse(condition)
XCTAssertEqual(a, b)
XCTAssertNotEqual(a, b)
XCTAssertNil(value)
XCTAssertNotNil(value)
XCTAssertThrowsError(try expression)
```

## Test Coverage Goals

- [ ] CLI output parsing (needs fixtures)
- [ ] Server state transitions
- [x] Path escaping (security)
- [x] Version parsing
- [x] Domain validation
- [x] File path handling
- [ ] Menu building logic
- [ ] Error handling

## CI Integration

Tests run automatically on:
- Every push to `main` or `develop`
- Every pull request
- Before releases

See `.github/workflows/build.yml`

## Manual Testing Checklist

Since some features require Symfony CLI:

### Server Management
- [ ] Start a stopped server
- [ ] Stop a running server  
- [ ] Start multiple servers
- [ ] Handle server start failure (port in use)
- [ ] Refresh server list

### PHP Versions
- [ ] Detect multiple PHP versions
- [ ] Show default PHP version (★)
- [ ] Set PHP as default (creates ~/.php-version)
- [ ] Copy PHP path
- [ ] Show in Finder

### Proxies
- [ ] List .wip domains
- [ ] Open proxy in browser
- [ ] Copy proxy URL
- [ ] Show proxy directory in Finder

### UI/UX
- [ ] Menu opens quickly
- [ ] Refresh works
- [ ] About window displays correctly
- [ ] Start at Login toggles
- [ ] Icons and fonts display properly
- [ ] Status dots show correct colors

### Integration
- [ ] Terminal opens with correct directory
- [ ] Server logs open in Terminal
- [ ] Browser opens with correct URL
- [ ] Finder shows correct path
- [ ] Copy to clipboard works

## Known Testing Limitations

1. **XCTest Availability**: Tests require full Xcode installation
2. **Executable Target**: Can't directly test `@testable import` with executable
3. **Symfony CLI Dependency**: Integration tests need CLI installed
4. **macOS Version**: Tests must run on macOS 13.0+

## Future Improvements

1. **Mock Symfony CLI**: Create test fixtures for CLI output
2. **Integration Tests**: Test actual CLI commands
3. **UI Tests**: XCUITest for menu interactions
4. **Performance Tests**: Measure parsing and refresh speed
5. **Coverage Reports**: Add code coverage tooling

## Debugging Tests

```bash
# Run with debug output
swift test --verbose

# Run single test
swift test --filter testPathEscaping

# Generate test report
swift test --enable-code-coverage
```

## Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Swift Testing Guide](https://swift.org/documentation/package-manager/#testing)
- [Writing Testable Code](https://developer.apple.com/videos/play/wwdc2017/414/)
