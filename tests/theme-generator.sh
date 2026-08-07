#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
wallpaper="$test_dir/wallpaper.png"

if command -v magick >/dev/null 2>&1; then
    magick -size 64x64 xc:'#336699' "$wallpaper"
elif command -v convert >/dev/null 2>&1; then
    convert -size 64x64 xc:'#336699' "$wallpaper"
else
    printf 'skip - ImageMagick is not available\n'
    exit 0
fi

HOME="$test_dir/home" THEME_NO_RELOAD=1 \
    "$repo_dir/dotfiles/.local/bin/apply-wallpaper-theme" "$wallpaper"

for generated in \
    .config/sway/colors.conf \
    .config/waybar/colors.css \
    .config/wofi/colors.css \
    .config/mako/colors \
    .config/foot/colors.ini \
    .config/gtk-3.0/colors.css \
    .config/gtk-4.0/colors.css; do
    [[ -s $test_dir/home/$generated ]]
done

grep -q 'Generated from the active wallpaper' \
    "$test_dir/home/.config/sway/colors.conf"
if grep -Rqs '/home/michael' "$test_dir/home"; then
    printf 'not ok - generated theme contains a hard-coded home path\n' >&2
    exit 1
fi
printf 'ok - wallpaper palette is generated for every configured component\n'
