#!/bin/bash

# Kill all running waybar instances
killall waybar

# Give it a moment to properly stop
sleep 0.5

# Restart waybar
waybar &
