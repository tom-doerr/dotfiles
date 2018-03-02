# Set history file size
HISTSIZE=1000000
HISTFILESIZE=2000000

# ALIAS
# Show battery stats
alias bat="watch 'upower -i /org/freedesktop/UPower/devices/battery_BAT0| grep -E \"time to empty|percentage\"'"
alias tw=timew


# Start tmux by default
#[[ $TERM != "screen" ]] && exec tmux
if [[ $TERM != "screen" ]] && ! tmux attach -t base;
then
    [[ $TERM != "screen" ]] && exec tmux new -s base
fi

# Immediately append commands to history
shopt -s histappend

# Immediately append commands to history
PROMPT_COMMAND="history -a;$PROMPT_COMMAND"

# Better navigation
alias ..="cd .."

# Change directory without cd
shopt -s autocd

# Change bash prompt text
export PS1="\w \$ "

# https://stackoverflow.com/questions/19595067/git-add-commit-and-push-commands-in-one
function lazygit() {
    git add .
    git commit -a -m "$1"
    git push
}

bind 'set completion-ignore-case on'

# Use vim-mode
set -o vi



