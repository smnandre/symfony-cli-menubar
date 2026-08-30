# Symfony CLI Menu Bar

> A native macOS menu bar app for managing local [Symfony CLI](https://github.com/symfony-cli/symfony-cli) servers.

![Symfony CLI Menu Bar](assets/symfony-cli-menubar.banner.jpg)

Access, start, and stop your local Symfony servers from the menu bar. Open them in your browser, view logs, manage PHP versions and proxy domains — without leaving your current context.

## Features

- **Server management**: view all your Symfony local servers at a glance; start and stop them directly from the menu
- **One-click browser open**: open any running server in your default browser instantly
- **Server logs**: jump straight to `symfony server:log` in Terminal, pre-filled for the right project
- **PHP versions**: see all installed PHP versions and set the default
- **Proxy domains**: manage `.wip` Symfony proxy domains
- **Update check**: compare the installed version with the published Homebrew cask and copy the upgrade command
- **Start at Login**: optionally launch on login so it is always available

## Requirements

- Apple Silicon Mac with macOS 14.0 or later
- [Symfony CLI](https://symfony.com/download) installed and available in your `PATH`

## Installation

Install Symfony CLI first if needed:

```bash
brew install symfony-cli/tap/symfony-cli
```

Install the app from its cask:

```bash
brew install --cask smnandre/tap/symfony-cli-menubar
```

The fully qualified command adds the tap and trusts this cask. After installation, the short cask name is enough:

```bash
brew upgrade --cask symfony-cli-menubar
brew uninstall --cask symfony-cli-menubar
```

If Homebrew reports that the cask is not trusted, trust that cask explicitly and retry:

```bash
brew trust --cask smnandre/tap/symfony-cli-menubar
```

Do not trust the entire tap when trusting this cask is sufficient.

### Migrating from a manual installation

Quit Symfony CLI Menu Bar, move the existing app from `/Applications` to the Trash, then run the cask installation command above. This is a clean migration from pre-1.0 builds: preferences, Terminal automation approval, and Start at Login registration are not migrated because 1.0 uses the new bundle identifier `dev.smnandre.symfony-cli-menubar`.

### Build from source

```bash
git clone https://github.com/smnandre/symfony-cli-menubar.git
cd symfony-cli-menubar

# Build and package
VERSION=0.0.0 SIGNING_MODE=adhoc ./scripts/package.sh release

# Run
open SymfonyCLIMenuBar.app
```

## Contributing

Contributions are welcome. Please open an issue before submitting a pull request for significant changes.
See [CONTRIBUTING.md](.github/CONTRIBUTING.md) for development guidelines.

## Thanks

Symfony CLI Menu Bar builds on top of remarkable open source work.

**[Symfony](https://symfony.com)**: the PHP framework this whole ecosystem is built on.
Fabien Potencier [@fabpot](https://github.com/fabpot) and the Symfony contributors.

**[Symfony CLI](https://github.com/symfony-cli/symfony-cli)**: the local server tooling this app brings to your menu
bar.
Fabien Potencier [@fabpot](https://github.com/fabpot) and Tugdual Saunier [@tucksaun](https://github.com/tucksaun).

## License

Released by [Simon André](https://smnandre.dev) under the [MIT License](LICENSE).

"Symfony" and the Symfony logo are registered trademarks of [Symfony SAS](https://symfony.com). The Symfony name and
logo are used in this project with the kind permission of the Symfony team. This project is not affiliated with or
endorsed by Symfony SAS or SensioLabs. See [NOTICE](NOTICE) for full trademark notices.
