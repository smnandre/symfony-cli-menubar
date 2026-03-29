# Code Signing & Notarization Setup

The release workflow (`.github/workflows/release.yml`) signs and notarizes the app for distribution outside the Mac App Store. This requires an Apple Developer account and five GitHub repository secrets.

## Prerequisites

- An [Apple Developer Program](https://developer.apple.com/programs/) membership
- A **Developer ID Application** certificate (not Mac App Distribution)
- An app-specific password for your Apple ID

## Required GitHub Secrets

Configure these in **Settings > Secrets and variables > Actions** in your GitHub repository.

| Secret | Description |
|--------|-------------|
| `APPLE_DEVELOPER_ID_P12` | Base64-encoded Developer ID Application certificate |
| `APPLE_DEVELOPER_ID_PASSWORD` | Password for the .p12 file |
| `APPLE_TEAM_ID` | Apple Developer Team ID (e.g. `ABCDE12345`) |
| `APPLE_ID` | Apple ID email used for notarization |
| `APPLE_NOTARIZATION_PASSWORD` | App-specific password for notarization |

## Step-by-step Setup

### 1. Export the Developer ID certificate

Open **Keychain Access**, find your "Developer ID Application" certificate, right-click and choose **Export**. Save as `.p12` with a password.

Alternatively, from the command line after installing from the Apple Developer portal:

```bash
security find-identity -v -p codesigning
# Look for "Developer ID Application: Your Name (TEAMID)"
```

### 2. Base64-encode the certificate

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
```

Paste the result as the `APPLE_DEVELOPER_ID_P12` secret.

### 3. Find your Team ID

Your Team ID is visible at [developer.apple.com/account](https://developer.apple.com/account) under Membership Details. It's a 10-character alphanumeric string.

### 4. Generate an app-specific password

1. Go to [account.apple.com](https://account.apple.com)
2. Sign in and go to **Sign-In and Security > App-Specific Passwords**
3. Generate a new password and use it as `APPLE_NOTARIZATION_PASSWORD`

## How Releases Work

1. Tag a commit: `git tag v1.2.3 && git push origin v1.2.3`
2. The workflow runs tests, builds, signs, notarizes, and creates a GitHub Release
3. Tags containing `alpha`, `beta`, or `rc` are marked as pre-releases

## Troubleshooting

**"No Developer ID Application identity found"** -- The P12 file doesn't contain a Developer ID Application certificate. Make sure you exported the correct certificate type (not "Apple Development" or "Mac App Distribution").

**Notarization fails with "Invalid credentials"** -- Verify that `APPLE_ID` is the email associated with your developer account and that `APPLE_NOTARIZATION_PASSWORD` is a valid app-specific password (not your account password).

**Notarization fails with "The software is not signed"** -- The app must be signed with `--options runtime` (hardened runtime). The `scripts/package.sh` script handles this automatically when `SIGNING_MODE=developer`.
