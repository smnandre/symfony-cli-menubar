# Privacy Policy

**Symfony CLI Menu Bar does not collect, store, or transmit any personal data.**

## What the app does

Symfony CLI Menu Bar is a local macOS utility. It:

- Runs the **Symfony CLI** as a subprocess on your machine to query your local server status
- Reads and writes preferences to your local macOS **UserDefaults**
- Opens URLs in your default browser when you explicitly click to do so

All of these operations happen entirely on your device.

## Network requests

The only outbound network request made by this app is an **optional software update check** via
the [Sparkle](https://sparkle-project.org) framework. When an update check occurs (automatically at most once per day,
or when you click "Check for Updates..."), the app contacts:

```
https://smnandre.github.io/symfony-cli-menubar/appcast.xml
```

This request contains no personal information beyond standard HTTP request metadata (IP address, User-Agent). No
tracking identifiers, usage data, or analytics are sent.

## No analytics, no telemetry

This app includes no analytics SDK, no crash reporter, and no telemetry of any kind. Nothing about your usage, your
projects, or your development environment is ever transmitted anywhere.

## Third-party dependencies

**Sparkle** handles update delivery. Sparkle's own privacy policy applies to the update check network request.
See https://sparkle-project.org.

## Changes

If this policy changes, the updated version will be committed to the repository alongside the release it applies to.

## Contact

Questions? Reach out to [Simon André](https://smnandre.dev).
