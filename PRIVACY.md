# Privacy Policy

**Symfony CLI Menu Bar does not collect, store, or transmit any personal data.**

## What the app does

Symfony CLI Menu Bar is a local macOS utility. It:

- Runs the **Symfony CLI** as a subprocess on your machine to query your local server status
- Reads and writes preferences to your local macOS **UserDefaults**
- Opens URLs in your default browser when you explicitly click to do so

All of these operations happen entirely on your device.

## Network requests

The only outbound network request made by this app is an optional, user-initiated software update check. When you click "Check for Updates...", the app contacts:

```
https://raw.githubusercontent.com/smnandre/homebrew-tap/main/Casks/symfony-cli-menubar.rb
```

This request contains no personal information beyond standard HTTP request metadata (IP address, User-Agent). No
tracking identifiers, usage data, or analytics are sent.

## No analytics, no telemetry

This app includes no analytics SDK, no crash reporter, and no telemetry of any kind. Nothing about your usage, your
projects, or your development environment is ever transmitted anywhere.

## Changes

If this policy changes, the updated version will be committed to the repository alongside the release it applies to.

## Contact

Questions? Reach out to [Simon André](https://smnandre.dev).
