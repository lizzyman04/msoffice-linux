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

usage() {
    echo "Usage: $0 [--help]"
    echo
    echo "Automates setting up Microsoft Office (2007-2016) on Linux via Wine and Bottles."
    echo
    echo "Options:"
    echo "  --help    Show this help message and exit"
    echo
    echo "Requirements:"
    echo "  - Linux with Flatpak support (apt/dnf/pacman)"
    echo "  - A legitimate Microsoft Office installer (setup.exe), 32-bit"
    exit 0
}

print_banner() {
    echo
    echo "  Play-MSOffice-on-Linux"
    echo
    echo "  A lightweight alternative to running Microsoft Office natively on Linux."
    echo
}

check_not_root() {
    if [[ "$EUID" -eq 0 ]]; then
        error "Do not run as root. Flatpak needs user context."
    fi
}

install_flatpak_if_missing() {
    if command -v flatpak &>/dev/null; then
        success "Flatpak already installed."
        return
    fi

    info "Flatpak not found. Detecting package manager..."

    if command -v apt &>/dev/null; then
        info "Using apt to install Flatpak..."
        sudo apt update -y
        sudo apt install -y flatpak
    elif command -v dnf &>/dev/null; then
        info "Using dnf to install Flatpak..."
        sudo dnf install -y flatpak
    elif command -v pacman &>/dev/null; then
        info "Using pacman to install Flatpak..."
        sudo pacman -Sy --noconfirm flatpak
    else
        error "No supported package manager found (apt/dnf/pacman). Install Flatpak manually and re-run."
    fi

    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
    success "Flatpak installed."
}

install_bottles() {
    if flatpak list --app 2>/dev/null | grep -q "com.usebottles.bottles"; then
        success "Bottles already installed."
        return
    fi

    info "Installing Bottles via Flatpak..."
    flatpak install -y flathub com.usebottles.bottles
    success "Bottles installed."
}

set_flatpak_permissions() {
    info "Setting Flatpak permissions for Bottles..."
    flatpak override com.usebottles.bottles --user --filesystem=xdg-data/applications
    flatpak override com.usebottles.bottles --user --filesystem=home
    success "Permissions set."
}

select_office_version() {
    echo
    echo "Select your Microsoft Office version:"
    echo "  1) Office 2007 / 2010"
    echo "  2) Office 2013"
    echo "  3) Office 2016"
    echo
    read -rp "Enter choice [1-3]: " VERSION_CHOICE < /dev/tty

    case "$VERSION_CHOICE" in
        1)
            RUNNER_NAME="pol-8.2"
            RUNNER_URL="https://www.playonlinux.com/wine/binaries/phoenicis/upstream-linux-x86/PlayOnLinux-wine-8.2-upstream-linux-x86.tar.gz"
            CONFIG_FILE="office2010.yml"
            ;;
        2)
            RUNNER_NAME="pol-4.3"
            RUNNER_URL="https://www.playonlinux.com/wine/binaries/phoenicis/upstream-linux-x86/PlayOnLinux-wine-4.3-upstream-linux-x86.tar.gz"
            CONFIG_FILE="office2013.yml"
            ;;
        3)
            RUNNER_NAME="pol-4.3"
            RUNNER_URL="https://www.playonlinux.com/wine/binaries/phoenicis/upstream-linux-x86/PlayOnLinux-wine-4.3-upstream-linux-x86.tar.gz"
            CONFIG_FILE="office2016.yml"
            ;;
        *)
            error "Invalid selection. Run the script again and choose 1, 2, or 3."
            ;;
    esac

    success "Selected runner: $RUNNER_NAME | Config: $CONFIG_FILE"
}

download_runner() {
    local runners_dir="$HOME/.var/app/com.usebottles.bottles/data/bottles/runners"
    local runner_dir="$runners_dir/$RUNNER_NAME"

    if [[ -d "$runner_dir" ]]; then
        success "Runner $RUNNER_NAME already exists. Skipping download."
        return
    fi

    info "Downloading Wine runner $RUNNER_NAME..."
    mkdir -p "$runner_dir"
    local tmp_archive
    tmp_archive="$(mktemp /tmp/wine-runner-XXXXXX.tar.gz)"

    if ! curl -L --progress-bar --retry 5 --retry-delay 3 --retry-all-errors \
              "$RUNNER_URL" -o "$tmp_archive" \
        || [[ ! -s "$tmp_archive" ]]; then
        rm -f "$tmp_archive"
        rmdir "$runner_dir" 2>/dev/null || true
        error "Failed to download Wine runner. Download manually and place it at:\n    $runner_dir\n  URL: $RUNNER_URL"
    fi

    info "Extracting runner..."
    tar -xzf "$tmp_archive" -C "$runner_dir" --strip-components=1
    rm -f "$tmp_archive"
    success "Runner $RUNNER_NAME installed."
}

resolve_config() {
    local configs_local="$SCRIPT_DIR/configs/$CONFIG_FILE"
    local raw_base="https://raw.githubusercontent.com/lizzyman04/msoffice-linux/main/configs"

    if [[ -f "$configs_local" ]]; then
        RESOLVED_CONFIG="$configs_local"
    else
        info "configs/ not found locally (pipe mode). Downloading $CONFIG_FILE..."
        local tmp_cfg
        tmp_cfg="$(mktemp /tmp/msoffice-config-XXXXXX.yml)"
        curl -sL "$raw_base/$CONFIG_FILE" -o "$tmp_cfg"
        RESOLVED_CONFIG="$tmp_cfg"
    fi

    success "Config resolved: $RESOLVED_CONFIG"
}

create_bottle() {
    info "Creating Bottles environment 'msoffice'..."
    flatpak run --command=bottles-cli com.usebottles.bottles new \
        --bottle-name msoffice \
        --environment custom \
        --arch win32 \
        --runner "$RUNNER_NAME"
    success "Bottle created."
}

apply_dll_overrides() {
    info "Applying DLL overrides..."

    flatpak run --command=bottles-cli com.usebottles.bottles reg add \
        -b msoffice \
        -k "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" \
        -v gdiplus \
        -d native,builtin \
        -t REG_SZ

    flatpak run --command=bottles-cli com.usebottles.bottles reg add \
        -b msoffice \
        -k "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" \
        -v riched20 \
        -d native,builtin \
        -t REG_SZ

    success "DLL overrides applied (gdiplus, riched20)."
}

ISO_MOUNT_DIR=""

cleanup_iso() {
    if [[ -n "$ISO_MOUNT_DIR" && -d "$ISO_MOUNT_DIR" ]]; then
        info "Unmounting ISO..."
        sudo umount "$ISO_MOUNT_DIR" 2>/dev/null || true
        rmdir "$ISO_MOUNT_DIR" 2>/dev/null || true
        ISO_MOUNT_DIR=""
    fi
}

mount_iso() {
    local iso_path="$1"
    ISO_MOUNT_DIR="$(mktemp -d /tmp/msoffice-iso-XXXXXX)"

    info "Mounting ISO: $iso_path"
    if ! sudo mount -o loop,ro "$iso_path" "$ISO_MOUNT_DIR" 2>/dev/null; then
        rmdir "$ISO_MOUNT_DIR"
        ISO_MOUNT_DIR=""
        error "Failed to mount ISO. Make sure 'sudo' is available and the file is a valid ISO."
    fi

    local exe
    exe="$(find "$ISO_MOUNT_DIR" -maxdepth 2 -iname "setup.exe" -print -quit 2>/dev/null)"

    if [[ -z "$exe" ]]; then
        warn "No setup.exe found in ISO. Contents of ISO root:"
        ls "$ISO_MOUNT_DIR"
        cleanup_iso
        error "No setup.exe found in ISO."
    fi

    SETUP_PATH="$exe"
    success "Found setup.exe in ISO: $SETUP_PATH"
}

prompt_setup_path() {
    echo
    warn "TIP: You can provide either a setup.exe or an .iso file. Place your Office installer in your current directory before continuing."
    echo

    while true; do
        read -rp "Enter the full path to your Office setup.exe or .iso (or drag the file here): " raw_path < /dev/tty

        # Strip surrounding single or double quotes (drag-and-drop often adds them)
        raw_path="${raw_path#\'}" ; raw_path="${raw_path%\'}"
        raw_path="${raw_path#\"}" ; raw_path="${raw_path%\"}"
        raw_path="${raw_path% }"  # trim trailing space

        # Resolve to absolute path
        local resolved
        resolved="$(realpath -m "$raw_path" 2>/dev/null || readlink -f "$raw_path" 2>/dev/null || echo "$raw_path")"

        # Validate: must exist and be .exe or .iso (case-insensitive)
        if [[ ! -f "$resolved" ]]; then
            echo -e "${RED}[x]${RESET} File not found: $resolved" >&2
            continue
        fi

        local lower="${resolved,,}"
        if [[ "$lower" != *.exe && "$lower" != *.iso ]]; then
            echo -e "${RED}[x]${RESET} Not an .exe or .iso file: $resolved" >&2
            continue
        fi

        if [[ "$lower" == *.iso ]]; then
            mount_iso "$resolved"
        else
            SETUP_PATH="$resolved"
            success "Installer found: $SETUP_PATH"
        fi

        echo
        local confirm
        read -rp "Proceed with installation? (y/n): " confirm < /dev/tty
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            break
        fi

        cleanup_iso
        echo "Re-enter the path."
    done
}

run_office_installer() {
    info "Launching Office installer inside bottle..."
    flatpak run --command=bottles-cli com.usebottles.bottles run \
        -b msoffice \
        -e "$SETUP_PATH"
    success "Office installer finished."
    cleanup_iso
}

run_integrate() {
    local integrate_local="$SCRIPT_DIR/integrate.sh"
    local raw_integrate="https://raw.githubusercontent.com/lizzyman04/msoffice-linux/main/integrate.sh"

    if [[ -f "$integrate_local" ]]; then
        info "Running desktop integration..."
        bash "$integrate_local"
    else
        info "Downloading and running integrate.sh..."
        local tmp_integrate
        tmp_integrate="$(mktemp /tmp/msoffice-integrate-XXXXXX.sh)"
        curl -sL "$raw_integrate" -o "$tmp_integrate"
        bash "$tmp_integrate"
        rm -f "$tmp_integrate"
    fi
}

main() {
    if [[ "${1:-}" == "--help" ]]; then
        usage
    fi

    print_banner
    check_not_root
    trap cleanup_iso EXIT

    # Resolve script directory — handle both local run and pipe-to-bash
    if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "bash" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    else
        SCRIPT_DIR=""
    fi

    install_flatpak_if_missing
    install_bottles
    set_flatpak_permissions
    select_office_version
    download_runner
    resolve_config
    create_bottle
    apply_dll_overrides
    prompt_setup_path
    run_office_installer
    run_integrate

    echo
    success "Installation complete. Your Office apps should now appear in your application menu."
    echo
}

main "$@"
