# Releases

Stable releases are Apple Silicon-only, Developer ID signed, notarized, and
distributed through the `smnandre/tap` Homebrew cask. GitHub Releases hosts the
DMG consumed by the cask.

The release workflow accepts stable `vX.Y.Z` tags. It runs the project checks,
builds and verifies the signed app and DMG, submits the DMG for notarization,
publishes the GitHub Release, and opens a pull request against the Homebrew tap.
It does not merge that pull request or update the public website.

Release preparation, tap publication, and website publication are reviewed as
separate pull requests. The public website is updated only after the cask is
available through Homebrew.

Maintainer credentials and operational procedures are intentionally not stored
in this repository.

## Failure boundaries

- A failed build, signature, notarization, or verification publishes nothing.
- A failed GitHub Release leaves no cask pull request.
- A failed cask pull request leaves the GitHub Release available but does not
  advertise an installable Homebrew update.
- A failed website publication leaves the previous public version visible.
