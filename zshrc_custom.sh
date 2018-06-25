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
        if [[ "$(task +ACTIVE 2>&1)" = *"No matches."* ]] 
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
    elif [[ $1 = "stop" ]]
    then
        uuids=$(task +ACTIVE _uuid)
        task $uuids stop
    else
        stop_taskwarrior_timewarrior
        timew start "$@"
    fi
}


bindkey '^R' history-incremental-search-backward

function t7() {
    echo "--------- IN 7 DAYS -----------"
    task sch:today+7d
    echo "--------- IN 6 DAYS -----------"
    task sch:today+6d
    echo "--------- IN 5 DAYS -----------"
    task sch:today+5d
    echo "--------- IN 4 DAYS -----------"
    task sch:today+4d
    echo "--------- IN 3 DAYS -----------"
    task sch:today+3d
    echo "---- THE DAY AFTER TOMORROW ---"
    task sch:today+2d
    echo "--------- TOMORROW ------------"
    task sch:today+1d
    echo "--------- TODAY ---------------"
    task sch:today
}

function timew_week() {
    clear
    echo "           0    1    2    3    4    5    6    7    8    9    10   11   12   13   14   15   16   17   18   19   20   21   22   23"
    timew week
}

