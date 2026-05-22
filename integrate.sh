#!/usr/bin/env bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

info()    { echo -e "${YELLOW}[*]${RESET} $*"; }
success() { echo -e "${GREEN}[+]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[x]${RESET} $*" >&2; exit 1; }

print_banner() {
    echo
    echo "  Play-MSOffice-on-Linux"
    echo
    echo "  A lightweight alternative to running Microsoft Office natively on Linux."
    echo
}

WRAPPERS=(ms-word ms-excel ms-powerpoint ms-outlook ms-onenote ms-access ms-publisher)

ICON_SIZES=(16 32 48 128 256)

install_wrappers() {
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    info "Installing wrapper scripts to $bin_dir..."
    for wrapper in "${WRAPPERS[@]}"; do
        local src="$SCRIPT_DIR/wrappers/$wrapper"
        if [[ ! -f "$src" ]]; then
            warn "Wrapper not found, skipping: $src"
            continue
        fi
        cp "$src" "$bin_dir/$wrapper"
        chmod +x "$bin_dir/$wrapper"
    done
    success "Wrappers installed."

    if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
        warn "$bin_dir is not in PATH."
        echo "    Add this to your ~/.bashrc:"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
}

install_desktop_files() {
    local apps_dir="$HOME/.local/share/applications"
    mkdir -p "$apps_dir"

    local desktop_src="$SCRIPT_DIR/desktop"
    if [[ ! -d "$desktop_src" ]]; then
        warn "desktop/ directory not found at $desktop_src — skipping .desktop install."
        return
    fi

    info "Installing .desktop entries to $apps_dir..."
    for f in "$desktop_src"/*.desktop; do
        [[ -f "$f" ]] || continue
        cp "$f" "$apps_dir/"
    done
    success ".desktop files installed."
}

install_icons() {
    local icons_src="$SCRIPT_DIR/icons"
    if [[ ! -d "$icons_src" ]]; then
        warn "icons/ directory not found at $icons_src — skipping icon install."
        return
    fi

    info "Installing icons..."
    for size in "${ICON_SIZES[@]}"; do
        local icon_dir="$HOME/.local/share/icons/hicolor/${size}x${size}/apps"
        mkdir -p "$icon_dir"
        for wrapper in "${WRAPPERS[@]}"; do
            local src="$icons_src/${size}x${size}/${wrapper}.png"
            if [[ -f "$src" ]]; then
                cp "$src" "$icon_dir/${wrapper}.png"
            fi
        done
    done
    success "Icons installed."
}

update_caches() {
    info "Updating desktop and icon caches..."
    update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
    gtk-update-icon-cache "$HOME/.local/share/icons/hicolor/" 2>/dev/null || true
    success "Caches updated."
}

set_mime_associations() {
    info "Setting MIME type associations..."

    local -A MIME_MAP=(
        ["ms-word.desktop"]="application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document application/vnd.ms-word.document.macroEnabled.12 application/rtf"
        ["ms-excel.desktop"]="application/vnd.ms-excel application/vnd.openxmlformats-officedocument.spreadsheetml.sheet application/vnd.ms-excel.sheet.macroEnabled.12 text/csv"
        ["ms-powerpoint.desktop"]="application/vnd.ms-powerpoint application/vnd.openxmlformats-officedocument.presentationml.presentation application/vnd.ms-powerpoint.presentation.macroEnabled.12"
        ["ms-outlook.desktop"]="x-scheme-handler/mailto message/rfc822"
        ["ms-access.desktop"]="application/msaccess application/vnd.ms-access"
        ["ms-publisher.desktop"]="application/vnd.ms-publisher application/x-mspublisher"
    )

    for desktop_file in "${!MIME_MAP[@]}"; do
        for mime in ${MIME_MAP[$desktop_file]}; do
            xdg-mime default "$desktop_file" "$mime" 2>/dev/null || true
        done
    done

    success "MIME associations set."
}

main() {
    print_banner

    if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "bash" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    else
        SCRIPT_DIR="$(pwd)"
    fi

    install_wrappers
    install_desktop_files
    install_icons
    update_caches
    set_mime_associations

    echo
    success "Desktop integration complete. All Office apps are now in your app menu."
    echo
}

main "$@"
