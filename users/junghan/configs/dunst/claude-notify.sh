#!/usr/bin/env bash

# Claude Code Notification Hook Script
# This script is called when Claude Code triggers a notification

# Parse JSON input from stdin
INPUT=$(cat)

# Extract message from JSON (simplified parsing)
MESSAGE=$(echo "$INPUT" | grep -o '"message":"[^"]*' | sed 's/"message":"//')

# Send notification with claude-code appname (triggers sound via dunst rule)
# The dunst rule [claudecode_sound] will handle the sound playback
notify-send "Claude Code" "${MESSAGE:-Notification}" -a "claude-code" -u normal
