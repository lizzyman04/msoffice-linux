# Play-MSOffice-on-Linux

**Run Microsoft Office on Linux — light, fast, and seamlessly native.**

A single script that sets up Microsoft Office (2007–2016) on Linux through Wine and Bottles, complete with native desktop integration. No virtual machines, no overhead — your Office apps look and feel like they belong right at home on your system.

> **Disclaimer:** This project does NOT provide, encourage, or support the use of pirated or cracked software. We assume you own a legitimate Microsoft Office license and have an official installer. This tool only automates the Linux setup process. If you do not have a valid license, consider free alternatives like [OnlyOffice](https://www.onlyoffice.com/) or [LibreOffice](https://www.libreoffice.org/).

## How It Works

Behind the scenes, msoffice-linux leans on Bottles (a sleek Wine frontend) to create a clean, isolated Windows compatibility layer. It grabs a battle-tested Wine runner, applies the right DLL overrides to keep things stable, installs Office inside the bottle, and then weaves it into your desktop — generating native `.desktop` entries so Word, Excel, and friends appear in your app menu and respond to file associations as if they'd been there all along.

## Features

- One-command install
- Supports Office 2007, 2010, 2013, and 2016 (32-bit)
- Full suite support: Word, Excel, PowerPoint, Outlook, OneNote, Access, Publisher
- Automatic Bottles and Wine runner setup
- Native .desktop entries with correct MIME types
- Wrapper scripts for opening files directly from the file manager
- Official Microsoft icons at multiple resolutions
- Uninstall script to cleanly remove everything

## Requirements

- Linux (Ubuntu, Debian, Mint, Fedora, Arch)
- Flatpak installed on your system
- A legitimate Microsoft Office installer (ISO or extracted folder, 32-bit)

## Quick Start

```sh
curl -sL https://raw.githubusercontent.com/lizzyman04/msoffice-linux/main/install.sh | bash
```

Or clone and run locally:

```sh
git clone https://github.com/lizzyman04/msoffice-linux.git
cd msoffice-linux
./install.sh
```

## Installation

Run the installer:

```sh
curl -sL https://raw.githubusercontent.com/lizzyman04/msoffice-linux/main/install.sh | bash
```

The script will:
1. Install Bottles and download the correct Wine runner
2. Create and configure the compatibility bottle
3. Ask you to provide the path to your Office `setup.exe`
4. Launch the Office installer inside the bottle
5. Set up desktop integration (icons, shortcuts, file associations)

Place your Office installer files in your working directory for convenience — when prompted, enter the path to `setup.exe` or drag the file into the terminal.

## Uninstalling

```sh
./uninstall.sh
```

Removes all wrapper scripts, desktop entries, and icons. Optionally removes the Bottles bottle and downloaded Wine runners.

## Supported Office Versions

| Version     | Wine Runner | Status    |
|-------------|-------------|-----------|
| Office 2007 | pol-8.2     | Supported |
| Office 2010 | pol-8.2     | Supported |
| Office 2013 | pol-4.3     | Supported |
| Office 2016 | pol-4.3     | Supported |

## Project Structure

```
msoffice-linux/
├── install.sh       # Main installer
├── integrate.sh     # Desktop integration (icons, shortcuts, MIME)
├── uninstall.sh     # Clean removal
├── configs/         # Bottles YAML configurations per Office version
├── wrappers/        # Launch scripts for each Office app
├── desktop/         # .desktop entry files
└── icons/           # SVG sources and generated PNGs
```

## Known Limitations

- Only Office 2007-2016 (32-bit) is supported via Wine.
- Office 365 and 2019+ require a full VM approach (see [LinOffice](https://github.com/eylenburg/linoffice) or [WinApps](https://github.com/winapps-org/winapps)).
- Outlook may have limited functionality — no native Exchange sync.
- Some advanced features (macros, VBA, COM add-ins) may not work perfectly under Wine.

## Contributing

PRs welcome. Please test on your distro and report any issues via the issue tracker.

## Credits

This project was built from scratch by [lizzyman04](https://github.com/lizzyman04). Similar efforts that served as useful reference:

- [tazihad/msoffice-bottle](https://github.com/tazihad/msoffice-bottle)
- [Rustring/MsOffice-On-WineBottles-Improved](https://github.com/Rustring/MsOffice-On-WineBottles-Improved)

## License

GPL-3.0. See [LICENSE](LICENSE) for details.
