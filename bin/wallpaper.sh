    #!/bin/bash

    WALLPAPER_DIR="$HOME/.config/hypr/wallpaper"
    HYPRPAPER_CONF="$HOME/.config/hypr/hyprpaper.conf"

    # Get a random wallpaper from the directory
    RANDOM_WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" \) | shuf -n 1)

    if [ -z "$RANDOM_WALLPAPER" ]; then
        echo "No wallpapers found in $WALLPAPER_DIR"
        exit 1
    fi

    # Update hyprpaper.conf
    echo "preload = $RANDOM_WALLPAPER" > "$HYPRPAPER_CONF"
    echo "wallpaper = ,$RANDOM_WALLPAPER" >> "$HYPRPAPER_CONF" # Apply to all monitors

    # Reload hyprpaper
    killall -e hyprpaper &
    sleep 1 # Give hyprpaper a moment to start
    hyprpaper &

    echo "Wallpaper set to: $RANDOM_WALLPAPER"
