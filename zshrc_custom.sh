ATHAME_ENABLED=0
export ATHAME_ENABLED

ATHAME_SHOW_MODE=0
export ATHAME_SHOW_MODE

ATHAME_VIM_PERSIST=1
export ATHAME_VIM_PERSIST

ATHAME_TEST_RC=~/.athamerc
export ATHAME_TEST_RC

set -o vi
setopt EXTENDED_GLOB

# Set history file size
HISTSIZE=1000000000
HISTFILESIZE=2000000000

enter_j(){
    j
    echo
    echo $ ls $(pwd)
    ls
    zle reset-prompt
}

enter_f(){
    f
    echo
    echo
    echo $ ls $(pwd)
    ls
    zle reset-prompt
}

clear2(){
    clear
    zle reset-prompt
}


bindkey '^R' history-incremental-search-backward

zle -N enter_j
bindkey '^[j' enter_j

zle -N enter_f
bindkey '^[f' enter_f

zle -N clear2
#bindkey '^[l' clear2

bindkey '^P' history-search-backward

DISABLE_AUTO_UPDATE=true

export neowatch_page_number_file_path='/var/tmp/neowatch_page_number_file'
export PATH="/home/tom/anaconda3/bin:$PATH"

source /usr/share/autojump/autojump.sh
source ~/git/dotfiles/shell_functions.sh
source ~/git/dotfiles/alias.sh

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh


