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

APPS=(word excel powerpoint outlook onenote access publisher)

print_banner() {
    echo
    echo "  msoffice-linux uninstaller"
    echo
}

confirm() {
    local prompt="$1"
    local reply
    read -rp "$prompt (y/n): " reply
    [[ "$reply" == "y" || "$reply" == "Y" ]]
}

remove_integration() {
    info "Removing wrapper scripts..."
    for app in "${APPS[@]}"; do
        rm -f "$HOME/.local/bin/ms-$app"
    done

    info "Removing .desktop entries..."
    for app in "${APPS[@]}"; do
        rm -f "$HOME/.local/share/applications/ms-$app.desktop"
    done

    info "Removing icons..."
    for app in "${APPS[@]}"; do
        rm -f "$HOME/.local/share/icons/hicolor/"*/apps/"ms-$app.png"
    done

    success "Desktop integration removed."
}

update_caches() {
    update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
    gtk-update-icon-cache "$HOME/.local/share/icons/hicolor/" 2>/dev/null || true
}

remove_bottle() {
    info "Removing Bottles bottle 'msoffice'..."
    flatpak run --command=bottles-cli com.usebottles.bottles remove msoffice
    success "Bottle removed."
}

remove_runners() {
    info "Removing Wine runners pol-8.2 and pol-4.3..."
    rm -rf \
        "$HOME/.var/app/com.usebottles.bottles/data/bottles/runners/pol-8.2" \
        "$HOME/.var/app/com.usebottles.bottles/data/bottles/runners/pol-4.3"
    success "Runners removed."
}

main() {
    print_banner
    warn "This will remove all msoffice-linux desktop integration from your system."
    echo

    confirm "Continue?" || { echo "Aborted."; exit 0; }

    echo
    remove_integration
    update_caches

    echo
    if confirm "Also remove the Bottles bottle 'msoffice'?"; then
        remove_bottle
    fi

    echo
    if confirm "Also remove downloaded Wine runners?"; then
        remove_runners
    fi

    echo
    success "Uninstall complete."
    echo
}

main "$@"
