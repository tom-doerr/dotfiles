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

# ALIAS
# Show battery stats
alias bat="watch 'upower -i /org/freedesktop/UPower/devices/battery_BAT0| grep -E \"time to empty|percentage\"'"

alias tw=timew
alias ng="/usr/local/lib/node_modules/@angular/cli/bin/ng"

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'


# Start tmux by default
#[[ $TERM != "screen" ]] && exec tmux
if [[ $TERM != "screen" ]] && ! tmux attach -t base;
then
    [[ $TERM != "screen" ]] && exec tmux new -s base
fi


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
        stop_taskwarrior_timewarrior
        task start $1
    else
        stop_taskwarrior_timewarrior
        timew start "$@"
    fi
}

bindkey '^R' history-incremental-search-backward
