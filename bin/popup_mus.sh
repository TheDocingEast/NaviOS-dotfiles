#!/bin/bash

URL=$(playerctl metadata mpris:artUrl 2>/dev/null)

# No image → exit quietly
if [[ -z "$URL" ]]; then
  exit 0
fi

IMG="/tmp/waybar-album.png"
curl -sL "$URL" -o "$IMG"

# Kill existing popups
pkill -f "yad --picture"

# Get cursor position (Hyprland)
eval $(hyprctl cursorpos -j | jq -r '"X=\(.x) Y=\(.y)"')

# Show popup
yad --picture --filename="$IMG" \
  --undecorated \
  --skip-taskbar \
  --no-buttons \
  --geometry=+$(($X + 10))+$(($Y + 10)) \
  --timeout=9999 &
