#!/bin/bash

# Get current layout for the first keyboard device
# current=$(hyprctl devices -j | jq -r '.keyboards[0].layout')
current=$(hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap')

echo "{ \"text\": \"$current\", \"tooltip\": \"Click to switch layout\" }"
