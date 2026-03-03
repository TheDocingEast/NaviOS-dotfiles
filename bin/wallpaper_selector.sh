#!/bin/bash

# Rofi Wallpaper Selector for Arch Linux
# This script allows you to select and set wallpapers using rofi

# Configuration
WALLPAPER_DIR="$HOME/.config/hypr/wallpaper"
CURRENT_WALLPAPER="$HOME/.config/hypr/wallpaper/.current_wallpaper"
CACHE_DIR="$HOME/.cache/wallpaper-selector"
THUMBNAIL_SIZE="800x800"

# Create directories if they don't exist
mkdir -p "$WALLPAPER_DIR"
mkdir -p "$CACHE_DIR"

# Check if wallpaper directory is empty
if [ -z "$(ls -A "$WALLPAPER_DIR")" ]; then
  notify-send "Wallpaper Selector" "No wallpapers found in $WALLPAPER_DIR"
  exit 1
fi

# Check for required dependencies
if ! command -v rofi &>/dev/null; then
  notify-send "Error" "rofi is not installed"
  exit 1
fi

if ! command -v convert &>/dev/null; then
  notify-send "Error" "ImageMagick is not installed. Install it with: sudo pacman -S imagemagick"
  exit 1
fi

# Generate thumbnails for preview
generate_thumbnails() {
  cd "$WALLPAPER_DIR" || exit 1

  find . -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | while read -r img; do
    img=$(basename "$img")
    thumbnail="$CACHE_DIR/${img%.*}.png"

    # Generate thumbnail if it doesn't exist or is older than original
    if [ ! -f "$thumbnail" ] || [ "$img" -nt "$thumbnail" ]; then
      convert "$img" -thumbnail "$THUMBNAIL_SIZE" "$thumbnail" 2>/dev/null
    fi
  done
}

# Generate thumbnails
generate_thumbnails

# Get list of image files
cd "$WALLPAPER_DIR" || exit 1
WALLPAPERS=$(find . -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -printf "%f\n" | sort)

# Check if any wallpapers were found
if [ -z "$WALLPAPERS" ]; then
  notify-send "Wallpaper Selector" "No image files found in $WALLPAPER_DIR"
  exit 1
fi

# Create rofi menu with image preview
show_menu() {
  echo "$WALLPAPERS" | rofi -dmenu -i \
    -theme-str 'window {width: 50%;}' \
    -show-icons \
    -preview-command 'echo -ne "\x00icon\x1f{1}" && cat "$HOME/.cache/wallpaper-selector/$(basename {1} | sed "s/\.[^.]*$/.png/")"' \
    -display-columns 1
}

# Alternative method using a custom rofi script mode
create_menu_entries() {
  while IFS= read -r wallpaper; do
    thumbnail="$CACHE_DIR/${wallpaper%.*}.png"
    if [ -f "$thumbnail" ]; then
      echo -en "$wallpaper\x00icon\x1f$thumbnail\n"
    else
      echo "$wallpaper"
    fi
  done <<<"$WALLPAPERS"
}

# Show rofi menu and get selection
SELECTED=$(
  create_menu_entries | rofi -dmenu -i \
    -theme-str 'window {width: 70%; location: south; anchor: south; y-offset: 30px;}' \
    -theme-str 'inputbar { enabled: false; }' \
    -theme-str 'listview {columns: 4; lines: 1; padding: 0;}' \
    -theme-str 'element {padding: 1px; orientation: vertical;}' \
    -theme-str 'element-icon {size: 10em;}' \
    -show-icons
)

# Exit if nothing was selected
if [ -z "$SELECTED" ]; then
  exit 0
fi

# Full path to selected wallpaper
WALLPAPER_PATH="$WALLPAPER_DIR/$SELECTED"

# Detect display server and set wallpaper accordingly
set_wallpaper() {
  if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    # Wayland compositors
    if command -v swaybg &>/dev/null; then
      # Kill existing swaybg instances
      pkill swaybg
      swaybg -i "$WALLPAPER_PATH" -m fill &
    elif command -v swww &>/dev/null; then
      swww img "$WALLPAPER_PATH" --transition-type random --transition-step 10 --transition-fps 60
    elif command -v hyprctl &>/dev/null; then
      # Hyprland
      hyprctl hyprpaper preload "$WALLPAPER_PATH"
      hyprctl hyprpaper wallpaper ",$WALLPAPER_PATH"
    else
      notify-send "Wallpaper Selector" "No supported Wayland wallpaper tool found"
      exit 1
    fi
  else
    # X11
    if command -v feh &>/dev/null; then
      feh --bg-fill "$WALLPAPER_PATH"
    elif command -v nitrogen &>/dev/null; then
      nitrogen --set-scaled "$WALLPAPER_PATH"
    elif command -v xwallpaper &>/dev/null; then
      xwallpaper --zoom "$WALLPAPER_PATH"
    else
      notify-send "Wallpaper Selector" "No supported X11 wallpaper tool found"
      exit 1
    fi
  fi
}

# Set the wallpaper
set_wallpaper

# Save current wallpaper path for persistence
echo "$WALLPAPER_PATH" >"$CURRENT_WALLPAPER"
ln -sf $WALLPAPER_PATH /home/thedocingeast/.config/hypr/wallpaper/current

# Send notification
notify-send "Wallpaper Changed" "Set to: $SELECTED"
