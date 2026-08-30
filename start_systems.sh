#!/usr/bin/env bash
# start_systems.sh — launch each system listed in systems.txt in its own tmux window.
# Usage: ./start_systems.sh [systems.txt]
set -uo pipefail

SYSTEMS_FILE="${1:-systems.txt}"
SESSION="systems"

if ! command -v tmux >/dev/null 2>&1; then
    echo "Error: tmux is not installed."
    exit 1
fi

if [[ ! -f "$SYSTEMS_FILE" ]]; then
    echo "Error: systems file '$SYSTEMS_FILE' not found."
    exit 1
fi

# Collect system names using the same filtering rules as downloader.sh.
systems=()
while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue
    [[ "${line:0:1}" == "#" ]] && continue
    systems+=("$line")
done < "$SYSTEMS_FILE"

if [[ ${#systems[@]} -eq 0 ]]; then
    echo "No systems found in '$SYSTEMS_FILE'."
    exit 1
fi

# Maximum panes per window — override with: MAX_PANES=6 ./start_systems.sh
MAX_PANES="${MAX_PANES:-4}"

# Kill any pre-existing session with the same name.
tmux kill-session -t "$SESSION" 2>/dev/null || true

# launch builds the command for one systems.txt entry.
#
# An entry may carry arguments after the system's name — "envoy -serve view
# cloudpicture". Most systems need none: they read systemconfig.json and run.
# envoy is the exception, because it is one binary with two shapes, a one-shot
# capture and a viewer, and which one it is comes from the command line. Without
# this it starts, prints its usage and exits, which is what it did the first time
# it was put in this file.
launch() {
    local entry="$1"
    local name="${entry%% *}"
    local args=""
    [[ "$entry" == *" "* ]] && args=" ${entry#* }"
    printf "cd '%s' && ./%s_rpi64%s" "$name" "$name" "$args"
}

# Create the session and start the first system in the initial pane.
first="${systems[0]}"
tmux new-session -d -s "$SESSION"
tmux send-keys -t "$SESSION" "$(launch "$first")" Enter
pane_count=1

for sys in "${systems[@]:1}"; do
    if [[ $pane_count -ge $MAX_PANES ]]; then
        # Current window is full — tile it and open a new window.
        tmux select-layout -t "$SESSION" tiled
        tmux new-window -t "$SESSION"
        pane_count=0
    else
        tmux split-window -t "$SESSION"
    fi
    tmux send-keys -t "$SESSION" "$(launch "$sys")" Enter
    ((pane_count++))
done

# Tile the last (possibly partial) window.
tmux select-layout -t "$SESSION" tiled

# Return focus to the first window.
tmux select-window -t "${SESSION}:^"

echo "Starting tmux session '$SESSION' with ${#systems[@]} system(s): ${systems[*]%% *}"

# Attach only when a person is running this.
#
# At boot this script is run by systemd (mbaigo-cloud.service), where there is
# no terminal: "tmux attach" then fails, and because it is the last command its
# non-zero status becomes the script's, so systemd reports the unit as failed
# and — with Restart=on-failure — starts tearing down a cloud that came up
# perfectly. The session exists either way; attaching is a convenience for the
# operator, not part of starting anything.
if [ -t 1 ]; then
    tmux attach-session -t "$SESSION"
fi
