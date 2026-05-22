# Icons

Office icons sourced from [sempostma/office365-icons](https://github.com/sempostma/office365-icons) (MIT License).

SVG fallbacks for Access and Publisher (not in upstream repo) are hand-crafted using Microsoft's official brand colors:
- Access: `#A4262C`
- Publisher: `#077568`

## Regenerating

```sh
cd icons/
./download-icons.sh
```

Requires one of: `librsvg2-bin` (preferred) or `imagemagick`.

```sh
# Ubuntu/Debian
sudo apt install librsvg2-bin

# Fedora
sudo dnf install librsvg2-tools

# Arch
sudo pacman -S librsvg
```

## Structure

```
icons/
├── svg/               # Source SVGs
├── ms-<app>-<size>.png  # Generated PNGs (16, 32, 48, 128, 256)
└── download-icons.sh  # Fetch + generate script
```
