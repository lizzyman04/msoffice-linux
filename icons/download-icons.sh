#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SVG_DIR="$SCRIPT_DIR/svg"
BASE_URL="https://raw.githubusercontent.com/sempostma/office365-icons/master/svg"
SIZES=(16 32 48 128 256)
APPS=(word excel powerpoint outlook onenote access publisher)

mkdir -p "$SVG_DIR"

# ── Detect converter ──────────────────────────────────────────────────────────
if command -v rsvg-convert &>/dev/null; then
    CONVERTER="rsvg"
elif command -v magick &>/dev/null; then
    CONVERTER="magick"
elif command -v convert &>/dev/null; then
    CONVERTER="imagemagick"
else
    echo "[x] No SVG converter found. Install one of: librsvg2-bin, imagemagick" >&2
    exit 1
fi
echo "[*] Using converter: $CONVERTER"

# ── Inline SVG fallbacks (Access + Publisher) ─────────────────────────────────
write_access_svg() {
    cat > "$SVG_DIR/access.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">
  <rect width="96" height="96" rx="12" fill="#A4262C"/>
  <text x="50%" y="58%" dominant-baseline="middle" text-anchor="middle"
        font-family="Segoe UI, Arial, sans-serif" font-weight="700"
        font-size="52" fill="white">A</text>
</svg>
SVG
}

write_publisher_svg() {
    cat > "$SVG_DIR/publisher.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">
  <rect width="96" height="96" rx="12" fill="#077568"/>
  <text x="50%" y="58%" dominant-baseline="middle" text-anchor="middle"
        font-family="Segoe UI, Arial, sans-serif" font-weight="700"
        font-size="52" fill="white">P</text>
</svg>
SVG
}

# ── Download SVGs ─────────────────────────────────────────────────────────────
echo
echo "[*] Downloading SVGs..."
for app in "${APPS[@]}"; do
    svg="$SVG_DIR/${app}.svg"
    if [[ "$app" == "access" ]]; then
        write_access_svg
        echo "    [fallback] access.svg (not in upstream repo)"
    elif [[ "$app" == "publisher" ]]; then
        write_publisher_svg
        echo "    [fallback] publisher.svg (not in upstream repo)"
    else
        curl -sL "$BASE_URL/${app}.svg" -o "$svg"
        echo "    [ok] ${app}.svg"
    fi
done

# ── Convert to PNG ────────────────────────────────────────────────────────────
convert_svg() {
    local app="$1" size="$2"
    local src="$SVG_DIR/${app}.svg"
    local out="$SCRIPT_DIR/ms-${app}-${size}.png"

    case "$CONVERTER" in
        rsvg)
            rsvg-convert -w "$size" -h "$size" "$src" -o "$out"
            ;;
        magick)
            magick -background none -density 300 -resize "${size}x${size}" "$src" "$out"
            ;;
        imagemagick)
            convert -background none -density 300 -resize "${size}x${size}" "$src" "$out"
            ;;
    esac
}

echo
echo "[*] Generating PNGs..."
for app in "${APPS[@]}"; do
    for size in "${SIZES[@]}"; do
        convert_svg "$app" "$size"
        echo "    [ok] ms-${app}-${size}.png"
    done
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo
total=$(( ${#APPS[@]} * ${#SIZES[@]} ))
echo "[+] Done. Generated $total PNG files across ${#SIZES[@]} sizes for ${#APPS[@]} apps."
echo "    Sizes: ${SIZES[*]}"
echo "    Apps:  ${APPS[*]}"
echo
