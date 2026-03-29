# Release Process

This project uses a professional two-phase release workflow: **Prepare** (via Pull Request) and **Release** (via Git Tag).

---

## Phase 1: Prepare (The Pull Request)

Before releasing a new version, you must prepare the codebase on a dedicated branch and merge it into `main`.

1.  **Create a Release Branch:**
    ```bash
    git checkout -b release/v1.0.0
    ```
2.  **Update the Version:**
    Edit `config/version.env` and update the version and build number:
    ```
    MARKETING_VERSION=1.0.0
    BUILD_NUMBER=1
    ```
3.  **Update the Changelog (`CHANGELOG.md`):**
    - Rename the `## [Unreleased]` section to `## [1.0.0] - YYYY-MM-DD`.
    - Create a new empty `## [Unreleased]` section at the top.
    - Ensure all notable changes are correctly categorized (Added, Changed, Fixed).
4.  **Open a Pull Request:**
    - Title: `Release v1.0.0`
    - Verify that all CI checks (tests, build) pass on the PR.
5.  **Merge into `main`:**
    Once verified, merge the PR into the `main` branch.

---

## Phase 2: Release (The Tag)

The actual release is triggered by pushing a version tag to the `main` branch.

1.  **Sync Local Main:**
    ```bash
    git checkout main
    git pull origin main
    ```
2.  **Create and Push Tag:**
    ```bash
    git tag v1.0.0
    git push origin v1.0.0
    ```
3.  **Automation Pipeline:**
    Pushing the tag triggers the `release.yml` workflow, which performs the following:
    - **Validation:** Runs a "Pre-flight Check" to ensure all signing secrets are present.
    - **Build & Sign:** Compiles the universal app, signs it with your Developer ID, and embeds Sparkle.
    - **Notarize:** Submits the app to Apple for notarization and staples the ticket.
    - **Package:** Creates a DMG and a ZIP for updates.
    - **Distribute:** Creates a GitHub Release, uploads all assets, and updates the website/appcast.

---

## Silent Releases (Pre-releases)

If you want to release a version without marking it as the "Latest Release" (e.g., for beta testing or internal use):

1.  Use a tag with a suffix: `v1.0.0-beta.1` or `v1.0.0-rc.1`.
2.  The workflow will automatically detect the suffix and mark the GitHub Release as a **"Pre-release"**.
3.  Users will not be automatically updated to this version unless their Sparkle configuration allows beta updates.

---

## Required Secrets

The following secrets must be configured in your GitHub repository settings:

| Secret | Purpose |
|---|---|
| `APPLE_DEVELOPER_ID_P12` | Base64-encoded Developer ID Application certificate (.p12) |
| `APPLE_DEVELOPER_ID_PASSWORD` | Password for the .p12 file |
| `APPLE_ID` | Apple ID used for notarization |
| `APPLE_NOTARIZATION_PASSWORD` | App-specific password for notarization |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `SPARKLE_PRIVATE_KEY` | EdDSA private key used to sign the ZIP for Sparkle |

The `SPARKLE_PUBLIC_KEY` is also required but is typically managed via script configuration.
