#!/usr/bin/env bash
# stop_systems.sh — send Ctrl+C to every window in the 'systems' tmux session,
#                   wait 3 seconds for graceful shutdown, then kill the session.
# Usage: ./stop_systems.sh
set -uo pipefail

SESSION="systems"

if ! command -v tmux >/dev/null 2>&1; then
    echo "Error: tmux is not installed."
    exit 1
fi

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "No tmux session named '$SESSION' found."
    exit 0
fi

echo "Sending Ctrl+C to all panes in session '$SESSION'..."
while IFS= read -r pane; do
    tmux send-keys -t "$pane" C-c ""
    echo "  Ctrl+C sent to pane $pane"
done < <(tmux list-panes -t "$SESSION" -F "#{pane_id}")

echo "Waiting 3 seconds for systems to shut down gracefully..."
sleep 3

echo "Killing tmux session '$SESSION'..."
tmux kill-session -t "$SESSION"
echo "Done."
