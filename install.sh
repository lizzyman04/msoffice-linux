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

    echo
    echo "Select architecture:"
    echo "  1) win32 — better for older Office versions, legacy add-ins and DLLs; apps may crash. (recommended for low-end PCs)"
    echo "  2) win64 — supports modern 64-bit installers and larger workloads; (recommended for higher-spec PCs — RAM/CPU)"
    echo
    read -rp "Enter choice [1-2]: " ARCH_CHOICE < /dev/tty

    case "$ARCH_CHOICE" in
        2) WINEARCH="win64" ;;
        *) WINEARCH="win32" ;;
    esac

    success "Selected runner: $RUNNER_NAME | Config: $CONFIG_FILE | Arch: $WINEARCH"
}

download_runner() {
    local runners_dir="$HOME/.var/app/com.usebottles.bottles/data/bottles/runners"
    local runner_dir="$runners_dir/$RUNNER_NAME"

    if [[ -d "$runner_dir" ]]; then
        success "Runner $RUNNER_NAME already exists. Skipping download."
        return
    fi

    # Check remote file size via HEAD request
    local size_bytes=0
    if command -v wget &>/dev/null; then
        size_bytes=$(wget --spider --server-response -q "$RUNNER_URL" 2>&1 \
            | grep -i "Content-Length" | tail -1 | awk '{print $2}' | tr -d '\r')
    elif command -v curl &>/dev/null; then
        size_bytes=$(curl -sI "$RUNNER_URL" \
            | grep -i "Content-Length" | tail -1 | awk '{print $2}' | tr -d '\r')
    fi
    size_bytes="${size_bytes:-0}"

    local size_mb=$(( size_bytes / 1024 / 1024 ))
    if [[ "$size_mb" -gt 100 ]]; then
        warn "The Wine runner download is approximately ${size_mb}MB. Additional ~50MB for core fonts and Visual C++ redistributables."
        local dl_confirm
        read -rp "Continue with download? (y/n): " dl_confirm < /dev/tty
        if [[ "$dl_confirm" != "y" && "$dl_confirm" != "Y" ]]; then
            echo
            echo "To install manually, run:"
            echo "  mkdir -p \"$runner_dir\""
            echo "  wget -c -O /tmp/wine-runner.tar.gz \"$RUNNER_URL\""
            echo "  tar -xzf /tmp/wine-runner.tar.gz -C \"$runner_dir\" --strip-components=1"
            exit 0
        fi
    fi

    mkdir -p "$runner_dir"
    local tmp_archive
    tmp_archive="$(mktemp /tmp/wine-runner-XXXXXX.tar.gz)"

    info "Downloading Wine runner $RUNNER_NAME..."

    local download_ok=false
    if command -v wget &>/dev/null; then
        if wget -c --progress=bar:force -O "$tmp_archive" "$RUNNER_URL" 2>&1; then
            download_ok=true
        fi
    fi

    if [[ "$download_ok" == false ]] && command -v curl &>/dev/null; then
        warn "wget failed or not available. Trying curl..."
        if curl -L --retry 3 --retry-delay 3 -o "$tmp_archive" "$RUNNER_URL"; then
            download_ok=true
        fi
    fi

    if [[ "$download_ok" == false ]] || [[ ! -s "$tmp_archive" ]]; then
        rm -f "$tmp_archive"
        rmdir "$runner_dir" 2>/dev/null || true
        echo
        echo "Both wget and curl failed. To install manually, run:"
        echo "  mkdir -p \"$runner_dir\""
        echo "  wget -c -O /tmp/wine-runner.tar.gz \"$RUNNER_URL\""
        echo "  tar -xzf /tmp/wine-runner.tar.gz -C \"$runner_dir\" --strip-components=1"
        error "Failed to download Wine runner."
    fi

    info "Extracting runner..."
    tar -xzf "$tmp_archive" -C "$runner_dir" --strip-components=1
    rm -f "$tmp_archive"
    success "Runner $RUNNER_NAME installed."
}

create_bottle() {
    local bottle_dir="$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/msoffice"
    local runner_bin="$HOME/.var/app/com.usebottles.bottles/data/bottles/runners/$RUNNER_NAME/bin/wine"

    if [[ -d "$bottle_dir" ]]; then
        success "Bottle 'msoffice' already exists. Skipping creation."
        return
    fi

    info "Initializing Wine prefix for bottle 'msoffice'..."
    mkdir -p "$bottle_dir"

    flatpak run --command=bash com.usebottles.bottles -c \
        "WINEPREFIX='$bottle_dir' WINEARCH='$WINEARCH' '$runner_bin' wineboot --init" 2>/dev/null || true
    sleep 3

    flatpak run --command=bash com.usebottles.bottles -c \
        "WINEPREFIX='$bottle_dir' '$runner_bin' reg add 'HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides' /v winemenubuilder.exe /d '' /f" 2>/dev/null || true

    info "Writing bottle.yml..."
    local config_src
    local tmp_config=""
    if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/configs/$CONFIG_FILE" ]]; then
        config_src="$SCRIPT_DIR/configs/$CONFIG_FILE"
    else
        info "configs/ not found locally — downloading $CONFIG_FILE from GitHub..."
        tmp_config="$(mktemp /tmp/msoffice-config-XXXXXX.yml)"
        curl -sL "https://raw.githubusercontent.com/lizzyman04/msoffice-linux/main/configs/$CONFIG_FILE" \
            -o "$tmp_config"
        config_src="$tmp_config"
    fi

    cp "$config_src" "$bottle_dir/bottle.yml"
    [[ "$WINEARCH" == "win64" ]] && sed -i "s/Arch: win32/Arch: win64/" "$bottle_dir/bottle.yml"
    [[ -n "$tmp_config" ]] && rm -f "$tmp_config"

    local creation_date
    creation_date="$(date +'%Y-%m-%d %H:%M:%S.%6N')"
    sed -i "1a Creation_Date: '$creation_date'" "$bottle_dir/bottle.yml"

    success "bottle.yml written."

    info "Applying DLL overrides to Wine registry..."
    flatpak run --command=bash com.usebottles.bottles -c \
        "WINEPREFIX='$bottle_dir' '$runner_bin' reg add 'HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides' /v gdiplus /d native,builtin /f" 2>/dev/null || true
    flatpak run --command=bash com.usebottles.bottles -c \
        "WINEPREFIX='$bottle_dir' '$runner_bin' reg add 'HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides' /v riched20 /d native,builtin /f" 2>/dev/null || true
    success "DLL overrides applied (gdiplus, riched20)."

    info "Verifying bottle is recognized by Bottles..."
    if flatpak run --command=bottles-cli com.usebottles.bottles list bottles 2>/dev/null | grep -q "msoffice"; then
        success "Bottle 'msoffice' recognized."
    else
        warn "Bottle not listed yet — Bottles may need to rescan. Continuing anyway."
    fi
}

install_dependencies() {
    local bottle_dir="$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/msoffice"
    local runner_bin="$HOME/.var/app/com.usebottles.bottles/data/bottles/runners/$RUNNER_NAME/bin/wine"
    local fonts_dir="$bottle_dir/drive_c/windows/Fonts"
    mkdir -p "$HOME/.cache"
    local tmp_deps
    tmp_deps="$(mktemp -d "$HOME/.cache/msoffice-deps-XXXXXX")"

    # --- Core Fonts ---
    info "Installing core fonts..."

    if ! command -v cabextract &>/dev/null; then
        info "cabextract not found. Installing..."
        if command -v apt &>/dev/null; then
            sudo apt install -y cabextract
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y cabextract
        elif command -v pacman &>/dev/null; then
            sudo pacman -Sy --noconfirm cabextract
        else
            warn "Cannot install cabextract (no apt/dnf/pacman). Skipping core fonts."
        fi
    fi

    if command -v cabextract &>/dev/null; then
        local font_cabs=(
            andale32.exe arial32.exe arialb32.exe comic32.exe courie32.exe
            georgi32.exe impact32.exe times32.exe trebuc32.exe verdan32.exe webdin32.exe
        )
        local font_base="https://sourceforge.net/projects/corefonts/files/the%20fonts/final"
        local font_tmp="$tmp_deps/fonts"
        mkdir -p "$font_tmp" "$fonts_dir"

        for cab in "${font_cabs[@]}"; do
            local cab_file="$font_tmp/$cab"
            if command -v wget &>/dev/null; then
                wget -q -O "$cab_file" "$font_base/$cab/download" 2>/dev/null || true
            elif command -v curl &>/dev/null; then
                curl -sL -o "$cab_file" "$font_base/$cab/download" 2>/dev/null || true
            fi
            [[ -s "$cab_file" ]] && cabextract -q -d "$font_tmp" "$cab_file" 2>/dev/null || true
        done

        find "$font_tmp" -maxdepth 1 -iname "*.ttf" -exec cp -f {} "$fonts_dir/" \;
        success "Core fonts installed."
    fi

    # --- vcredist 2012 ---
    info "Installing Visual C++ 2012..."
    local vc2012_url="https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe"
    local vc2012_file="$tmp_deps/vcredist2012_x86.exe"
    local download_ok=false
    if command -v wget &>/dev/null; then
        wget -q -O "$vc2012_file" "$vc2012_url" 2>/dev/null && download_ok=true || true
    fi
    if [[ "$download_ok" == false ]] && command -v curl &>/dev/null; then
        curl -sL -o "$vc2012_file" "$vc2012_url" 2>/dev/null && download_ok=true || true
    fi
    if [[ "$download_ok" == true && -s "$vc2012_file" ]]; then
        flatpak run --command=bash com.usebottles.bottles -c \
            "WINEPREFIX='$bottle_dir' WINEDLLOVERRIDES='winemenubuilder.exe=' '$runner_bin' '$vc2012_file' /quiet /norestart" 2>/dev/null || true
        success "Visual C++ 2012 installed."
    else
        warn "Failed to download vcredist 2012. Skipping."
    fi

    # --- vcredist 2019 ---
    info "Installing Visual C++ 2019..."
    local vc2019_url="https://aka.ms/vs/16/release/vc_redist.x86.exe"
    local vc2019_file="$tmp_deps/vcredist2019_x86.exe"
    download_ok=false
    if command -v wget &>/dev/null; then
        wget -q -O "$vc2019_file" "$vc2019_url" 2>/dev/null && download_ok=true || true
    fi
    if [[ "$download_ok" == false ]] && command -v curl &>/dev/null; then
        curl -sL -o "$vc2019_file" "$vc2019_url" 2>/dev/null && download_ok=true || true
    fi
    if [[ "$download_ok" == true && -s "$vc2019_file" ]]; then
        flatpak run --command=bash com.usebottles.bottles -c \
            "WINEPREFIX='$bottle_dir' WINEDLLOVERRIDES='winemenubuilder.exe=' '$runner_bin' '$vc2019_file' /quiet /norestart" 2>/dev/null || true
        success "Visual C++ 2019 installed."
    else
        warn "Failed to download vcredist 2019. Skipping."
    fi

    rm -rf "$tmp_deps"
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
    ISO_MOUNT_DIR="$(mktemp -d "$HOME/.cache/msoffice-iso-XXXXXX")"

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
        raw_path="${raw_path/#\~/$HOME}"  # expand leading tilde

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
    local bottle_dir="$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/msoffice"
    local runner_bin="$HOME/.var/app/com.usebottles.bottles/data/bottles/runners/$RUNNER_NAME/bin/wine"
    local WINE_LOG="$HOME/.cache/msoffice-install.log"

    info "Launching Office installer inside bottle..."
    flatpak run --command=bash com.usebottles.bottles -c \
        "WINEPREFIX='$bottle_dir' WINEDLLOVERRIDES='winemenubuilder.exe=' '$runner_bin' '$SETUP_PATH'" 2>"$WINE_LOG"

    local real_errors
    real_errors="$(grep 'err:' "$WINE_LOG" \
        | grep -v 'get_stub_manager_from_ipid\|NtFsControlFile' \
        | sort -u)"

    if [[ -n "$real_errors" ]]; then
        warn "Some Wine errors occurred during installation (this may be normal):"
        echo "$real_errors" | head -20 | sed 's/^/    /'
        echo "Full log saved to: $WINE_LOG"
    else
        info "Installation log saved to: $WINE_LOG"
    fi

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
    create_bottle
    install_dependencies
    prompt_setup_path
    run_office_installer
    run_integrate

    echo
    success "Installation complete. Your Office apps should now appear in your application menu."
    echo
}

main "$@"
