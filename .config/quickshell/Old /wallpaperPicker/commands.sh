#!/bin/bash
# $1 = full path to selected wallpaper

if command -v swww &>/dev/null; then
    swww img "$1" --transition-type random --transition-step 10 --transition-fps 60
elif command -v awww &>/dev/null; then
    awww img "$1" --transition-type random --transition-step 10 --transition-fps 60
elif command -v hyprctl &>/dev/null; then
    hyprctl hyprpaper preload "$1"
    hyprctl hyprpaper wallpaper ",$1"
elif command -v swaybg &>/dev/null; then
    pkill swaybg
    swaybg -i "$1" -m fill &
fi

# Save current wallpaper reference
echo "$1" > "$(dirname "$1")/.current_wallpaper"
ln -sf "$1" "$(dirname "$1")/current"

notify-send -t 2000 "Wallpaper Changed" "$(basename "$1")"
