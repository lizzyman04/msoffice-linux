# Play-MSOffice-on-Linux

A lightweight alternative for running Microsoft Office natively on Linux.

## About

A single install script that automates setting up Microsoft Office (2007-2016) on Linux through Wine and Bottles, with native desktop integration. No VMs, no overhead — Office runs as if it were a native app.

## Features

- One-command install
- Supports Office 2007, 2010, 2013, and 2016 (32-bit)
- Automatic Bottles and Wine runner setup
- Native .desktop entries with correct MIME types
- Wrapper scripts for opening files directly from the file manager
- Proper icon integration at multiple sizes
- Uninstall script to cleanly remove everything

## Requirements

- Linux (Ubuntu, Debian, Mint, Fedora, Arch)
- Flatpak installed on your system
- A legitimate Microsoft Office installer (ISO or folder, 32-bit)

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

## Supported Office Versions

| Version    | Wine Runner | Status |
|------------|-------------|--------|
| Office 2007 | pol-8.2    | Supported |
| Office 2010 | pol-8.2    | Supported |
| Office 2013 | pol-4.3    | Supported |
| Office 2016 | pol-4.3    | Supported |

## Credits

This project was lovingly built from scratch by [me](https://github.com/lizzyman04). Along the way, I stumbled upon a few kindred efforts in the community that served as invaluable references:

- [tazihad/msoffice-bottle](https://github.com/tazihad/msoffice-bottle)
- [Rustring/MsOffice-On-WineBottles-Improved](https://github.com/Rustring/MsOffice-On-WineBottles-Improved)

A heartfelt tip of the hat to everyone documenting this space — we build better things together.

## License

GPL-3.0. See [LICENSE](LICENSE) for details.
