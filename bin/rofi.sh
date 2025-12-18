#!/bin/bash
# Проверяем Wayland
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
  rofi -show combi -wayland-1 -layer overlay -normal-window
else
  rofi -show combi
fi
