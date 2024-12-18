# Set history file size
HISTSIZE=1000000
HISTFILESIZE=2000000

# ALIAS
# Show battery stats
alias bat="watch 'upower -i /org/freedesktop/UPower/devices/battery_BAT0| grep -E \"time to empty|percentage\"'"

alias vi='nvim'

alias tw=timew
alias ng="/usr/local/lib/node_modules/@angular/cli/bin/ng"

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi


## Start tmux by default
#if [[ $(tput cols) != 60 ]]
#then
#    if [[ $TERM != "screen" ]] && ! tmux attach -dt base;
#    then
#        [[ $TERM != "screen" ]] && exec tmux new -s base
#    fi
#else
#    if [[ $TERM != "screen" ]] && ! tmux attach -dt smartphone;
#    then
#        [[ $TERM != "screen" ]] && exec tmux new -s smartphone
#    fi
#
#fi

# Immediately append commands to history
PROMPT_COMMAND="history -a; history -n" 

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

# Use vim-mode
set -o vi

# Extract files with ex command
ex ()
{
  if [ -f $1 ] ; then
    case $1 in
      *.tar.bz2)   tar xjf $1   ;;
      *.tar.gz)    tar xzf $1   ;;
      *.bz2)       bunzip2 $1   ;;
      *.rar)       unrar x $1     ;;
      *.gz)        gunzip $1    ;;
      *.tar)       tar xf $1    ;;
      *.tbz2)      tar xjf $1   ;;
      *.tgz)       tar xzf $1   ;;
      *.zip)       unzip $1     ;;
      *.Z)         uncompress $1;;
      *.7z)        7z x $1      ;;
      *)           echo "'$1' cannot be extracted via ex()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# Function for adding batch tasks to taskwarrior

function tb() {
    task add "$@" wait:friday scheduled:friday
}

function stop_taskwarrior_timewarrior() {
        if [[ "$(task +ACTIVE 2>&1)" == "No matches." ]]
        then
            timew stop
        else
            task +ACTIVE done
        fi
}


function ts() {
    if [[ $1 == "" ]] 
    then
        stop_taskwarrior_timewarrior
    elif [[ $1 = "tom" ]]
    then
        task timeboxing_tomorrow
    elif [[ $1 =~ ^-?[0-9]+$ ]]
    then
        uuid=$(task $1 _uuid)
        stop_taskwarrior_timewarrior
        task start $uuid
    else
        stop_taskwarrior_timewarrior
        timew start "$@"
    fi
}



source ~/git/dotfiles/shell_functions.sh
source ~/git/dotfiles/alias.sh
source ~/git/dotfiles/shell_settings.sh

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


# JINA_CLI_BEGIN

## autocomplete
_jina() {
  COMPREPLY=()
  local word="${COMP_WORDS[COMP_CWORD]}"

  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$(jina commands)" -- "$word") )
  else
    local words=("${COMP_WORDS[@]}")
    unset words[0]
    unset words[$COMP_CWORD]
    local completions=$(jina completions "${words[@]}")
    COMPREPLY=( $(compgen -W "$completions" -- "$word") )
  fi
}

complete -F _jina jina

# session-wise fix
ulimit -n 4096
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
# default workspace for Executors

# JINA_CLI_END










## >>> conda initialize >>>
## !! Contents within this block are managed by 'conda init' !!
#__conda_setup="$('/home/tom/anaconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
#if [ $? -eq 0 ]; then
#    eval "$__conda_setup"
#else
#    if [ -f "/home/tom/anaconda3/etc/profile.d/conda.sh" ]; then
#        . "/home/tom/anaconda3/etc/profile.d/conda.sh"
#    else
#        export PATH="/home/tom/anaconda3/bin:$PATH"
#    fi
#fi
#unset __conda_setup
## <<< conda initialize <<<
#

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"
source /home/tom/git/scripts/k.sh
