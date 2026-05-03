#!/bin/bash
# Generates thumbnails for all wallpapers.
# $1 = shell directory (Quickshell.shellDir)

SHELL_DIR="$1"
CONFIG="$SHELL_DIR/config.json"

WALLPAPER_PATH=$(jq -r '.wallpaper_path' "$CONFIG")
CACHE_PATH=$(jq -r '.cache_path' "$CONFIG")

mkdir -p "$CACHE_PATH"

find "$WALLPAPER_PATH" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) | while read -r img; do
    name=$(basename "$img")
    thumb="$CACHE_PATH/$name"
    if [ ! -f "$thumb" ] || [ "$img" -nt "$thumb" ]; then
        # [0] берёт только первый кадр — нужно для GIF и многостраничных файлов
        convert "${img}[0]" -thumbnail 800x500^ -gravity center -extent 800x500 "$thumb" 2>/dev/null
        echo "Cached: $name"
    fi
done
