#!/bin/bash
# Get project info for tmux status bar
PANE_PATH="$1"
cd "$PANE_PATH" 2>/dev/null || exit

# Get git branch if in git repo
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# Get project name (basename of git root or current dir)
if git rev-parse --git-dir > /dev/null 2>&1; then
    PROJECT=$(basename "$(git rev-parse --show-toplevel)")
else
    PROJECT=$(basename "$PANE_PATH")
fi

# Output format
if [ -n "$GIT_BRANCH" ]; then
    echo "$PROJECT:$GIT_BRANCH"
else
    echo "$PROJECT"
fi