#!/bin/bash

# Kill all running waybar instances
killall quickshell

# Give it a moment to properly stop
sleep 0.5

# Restart waybar
quickshell &
