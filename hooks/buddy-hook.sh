#!/bin/bash
# Claude Code hook — writes state to ~/.codebuddy/state.json
# Usage: buddy-hook.sh <state>
# States: idle, thinking, coding, running, error, success, dropped

STATE="${1:-idle}"
STATE_FILE="$HOME/.codebuddy/state.json"
CONTEXT=""
MENTIONED=false

if [ ! -t 0 ]; then
    INPUT=$(cat)
    TOOL=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
    FILE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); i=d.get('tool_input',{}); print(i.get('file_path', i.get('command', i.get('pattern', ''))))" 2>/dev/null)
    if echo "$INPUT" | grep -qi "codebuddy\|buddy\|oki shiba\|buru"; then
        MENTIONED=true
        STATE="success"
        CONTEXT="noticed you mentioned me!"
    elif [ -n "$TOOL" ]; then
        CONTEXT="${TOOL}"
        if [ -n "$FILE" ]; then
            BASENAME=$(basename "$FILE" 2>/dev/null || echo "$FILE")
            CONTEXT="${TOOL}: ${BASENAME}"
        fi
    fi
fi

mkdir -p "$HOME/.codebuddy"
python3 -c "
import json
d = {'state': '$STATE', 'context': '$CONTEXT', 'mentioned': $( [ "$MENTIONED" = true ] && echo 'true' || echo 'false' )}
print(json.dumps(d))
" > "$STATE_FILE"
