#!/bin/bash
# CodeBuddy installer — sets up hooks, commands, and directories
set -e

echo "🐕 Installing CodeBuddy..."

CODEBUDDY_DIR="$HOME/.codebuddy"
CLAUDE_DIR="$HOME/.claude"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Create directories
mkdir -p "$CODEBUDDY_DIR/hooks"
mkdir -p "$CLAUDE_DIR/commands"

# Copy hook script
cp "$PROJECT_DIR/hooks/set-state.sh" "$CODEBUDDY_DIR/hooks/"
cp "$PROJECT_DIR/.claude/commands/codebuddy.md" "$CLAUDE_DIR/commands/"
chmod +x "$CODEBUDDY_DIR/hooks/set-state.sh"

# Copy buddy-hook.sh (the main hook that claude code calls)
cat > "$CODEBUDDY_DIR/hooks/buddy-hook.sh" << 'HOOK'
#!/bin/bash
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
python3 -c "
import json
d = {'state': '$STATE', 'context': '$CONTEXT', 'mentioned': $( [ "$MENTIONED" = true ] && echo 'true' || echo 'false' )}
print(json.dumps(d))
" > "$STATE_FILE"
HOOK
chmod +x "$CODEBUDDY_DIR/hooks/buddy-hook.sh"

# Write default state
echo '{"state":"idle","context":null,"mentioned":false}' > "$CODEBUDDY_DIR/state.json"

# Add hooks to claude settings if not already there
SETTINGS="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS" ]; then
    # Check if hooks already exist
    if grep -q "buddy-hook" "$SETTINGS" 2>/dev/null; then
        echo "  Hooks already configured in settings.json"
    else
        echo "  ⚠️  Add CodeBuddy hooks to $SETTINGS manually (see README)"
    fi
else
    # Create settings with hooks
    cat > "$SETTINGS" << 'SETTINGS'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|NotebookEdit",
        "hooks": [{"type": "command", "command": "bash ~/.codebuddy/hooks/buddy-hook.sh coding"}]
      },
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "bash ~/.codebuddy/hooks/buddy-hook.sh running"}]
      },
      {
        "matcher": "Grep|Glob|Read|Agent|WebSearch|WebFetch",
        "hooks": [{"type": "command", "command": "bash ~/.codebuddy/hooks/buddy-hook.sh thinking"}]
      }
    ],
    "PostToolUse": [
      {"hooks": [{"type": "command", "command": "bash ~/.codebuddy/hooks/buddy-hook.sh thinking"}]}
    ],
    "Notification": [
      {"hooks": [{"type": "command", "command": "bash ~/.codebuddy/hooks/buddy-hook.sh success"}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "bash ~/.codebuddy/hooks/buddy-hook.sh idle"}]}
    ]
  }
}
SETTINGS
    echo "  Created settings.json with hooks"
fi

# Build the app
echo "  Building CodeBuddy..."
cd "$PROJECT_DIR"
swift build -c release 2>/dev/null && echo "  Built successfully" || echo "  ⚠️  Build failed — run 'swift build' manually"

echo ""
echo "✅ CodeBuddy installed!"
echo ""
echo "  Run:     cd $PROJECT_DIR && .build/release/CodeBuddy"
echo "  Skill:   /codebuddy happy"
echo "  Config:  ~/.codebuddy/llm.json (optional — for AI-generated responses)"
echo ""
