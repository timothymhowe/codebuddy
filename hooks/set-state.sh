#!/bin/bash
# Usage: set-state.sh <state> [message]
# States: idle, thinking, coding, running, error, success

STATE="${1:-idle}"
MESSAGE="${2:-null}"

STATE_DIR="$HOME/.codebuddy"
STATE_FILE="$STATE_DIR/state.json"

mkdir -p "$STATE_DIR"

if [ "$MESSAGE" = "null" ]; then
    echo "{\"state\":\"$STATE\",\"message\":null}" > "$STATE_FILE"
else
    echo "{\"state\":\"$STATE\",\"message\":\"$MESSAGE\"}" > "$STATE_FILE"
fi
