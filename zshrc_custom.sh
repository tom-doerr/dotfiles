ATHAME_ENABLED=0
export ATHAME_ENABLED

ATHAME_SHOW_MODE=0
export ATHAME_SHOW_MODE

ATHAME_VIM_PERSIST=1
export ATHAME_VIM_PERSIST

ATHAME_TEST_RC=~/.athamerc
export ATHAME_TEST_RC

set -o vi

# Set history file size
HISTSIZE=1000000
HISTFILESIZE=2000000


# Start tmux by default
#[[ $TERM != "screen" ]] && exec tmux
if [[ $TERM != "screen" ]] && ! tmux attach -t base;
then
    [[ $TERM != "screen" ]] && exec tmux new -s base
fi


bindkey '^R' history-incremental-search-backward

source ~/git/dotfiles/shell_functions.sh
source ~/git/dotfiles/alias.sh
