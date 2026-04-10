#!/bin/bash
# Test a specific animation clip by symlinking it as idle2
# Usage: test_anim.sh <clip_name>
# Example: test_anim.sh walk

CLIP="${1:-idle2}"
ANIMS="$HOME/Projects/codebuddy/models/chubby/anims"

echo "Testing: $CLIP"
# Backup real idle2
cp "$ANIMS/idle2.dae" "$ANIMS/_backup_idle2.dae" 2>/dev/null
# Swap in the test clip
cp "$ANIMS/$CLIP.dae" "$ANIMS/idle2.dae"
# Restart buddy
pkill -f CodeBuddy 2>/dev/null
sleep 0.3
cd "$HOME/Projects/codebuddy" && .build/debug/CodeBuddy &
echo "Playing $CLIP as idle loop. Press enter when done."
read
# Restore
cp "$ANIMS/_backup_idle2.dae" "$ANIMS/idle2.dae"
