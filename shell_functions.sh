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

wait_if_process_running() {
    if [[  $(ps -aux | ag ".*$2.*task +ACTIVE done.*") != "" ]]
    then
        sleep ${1-"0.001"}
        wait_if_process_running $@
    fi

}

stop_taskwarrior_timewarrior() {
        if [[ "$(task +ACTIVE 2>&1)" = *"No matches."* ]] 
        then
            timew stop
        else
            timew stop
            task +ACTIVE done
            wait_if_process_running 0.0001 $!
        fi
        # ~/git/scripts/tw_hist.py $(tw get dom.active.tag.1)
}

ts_start_task() {
    while true; do
        task start "$@"
        if [[ "$(task "$@" +ACTIVE 2>&1)" != "No matches." ]] 
        then
            break
            echo "Task not started, retrying..."  
        fi
        sleep 1
    done

}

ts() {
    if [[ $1 == "" ]] 
    then
        stop_taskwarrior_timewarrior
    elif [[ $1 =~ ^-?[0-9]+$ ]]
    then
        uuid=$(task $1 _uuid)
        stop_taskwarrior_timewarrior
        ts_start_task $uuid
    elif [[ $1 = "stop" ]]
    then
        uuids=$(task +ACTIVE _uuid)
        task $uuids stop
    elif [[ $1 = "ss" ]]
    then
        uuids=$(task +ACTIVE _uuid)
        task $uuids stop
        if [[ $2 != "" ]]
        then
            ts "${@:2}"
        fi
    else
        tags_to_add=''
        for e in $@
        do
            tags_to_add_tmp=$(cat ~/git/private/tags.config | jq -r "."$e )
            if [[ $tags_to_add_tmp != "null" ]]
            then
                tags_to_add=$tags_to_add" "$tags_to_add_tmp
                echo "tags_to_add: "$tags_to_add
            fi
        done    
        stop_taskwarrior_timewarrior
        timew start $tags_to_add $@
    fi
}


at() {
    timew stop && timew cont && timew @1 tag $@
}

rt() {
    timew stop && timew cont && timew @1 untag $@
}


t7() {
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

timew_week() {
    if [[ $1 = '' ]]
    then
        freq=30
    else
        freq=$1
    fi

        ~/git/scripts/neowatch timew :color week

}

swatch() {
    while true
    do
        swatch_output=$($@)
        padding_output=''
        number_of_lines_output=$(echo $swatch_output | wc -l)
        let "number_of_lines_padding = $(tput lines) - $number_of_lines_output"
        for i in {2..$number_of_lines_padding}
        do
            padding_output+='\n'
        done
        $@
        echo $padding_output
        sleep 1
    done
}

td() {
    if [[ $1 == "" ]]
    then
        rt "$(t _get $(t +ACTIVE _uuid).description)"
    else
        task done $@
    fi
}

pa() {
    description_string="$@"
    task $(t +ACTIVE _uuid) duplicate description:$description_string
}

rb() {
    tmux split-window -v -t "$pane" "watch --color -n 0,1 task review_bucket_items"
}

sm() {
    if [[ $1 =~ ^-?[0-9]+$ ]]
    then
        task $@ mod +sm
    else
        task add $@ +sm
    fi
}

np() {
    current_page=$(cat $neowatch_page_number_file_path)
    let "current_page += 1"
    echo $current_page > $neowatch_page_number_file_path
}

pp() {
    current_page=$(cat $neowatch_page_number_file_path)
    if [[ $current_page > 0 ]]
    then
        let "current_page -= 1"
    fi
    echo $current_page > $neowatch_page_number_file_path
}

ggp() {
    current_page=1
    echo $current_page > $neowatch_page_number_file_path
}


get_first_task() {
    number_top_task_r1=$(bash -c 'task '$@' | awk '"'"'NR==3{print $1}'"'"'')    
    number_top_task_r1_nocolor=$(echo $number_top_task_r1 | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g")
    if [[ $number_top_task_r1_nocolor == '' ]]
    then 
        number_top_task_r1=$(bash -c 'task '$@' | awk '"'"'NR==3{print $2}'"'"'')    
        number_top_task_r1_nocolor=$(echo $number_top_task_r1 | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g")
    fi
    echo $number_top_task_r1_nocolor
}

start_first_task() {
    echo 'task '$@
    stop_taskwarrior_timewarrior
    number_top_task_r1_nocolor=$(get_first_task $@)
    task start $number_top_task_r1_nocolor
}

rs() {
    start_first_task report1
}

ds() {
    start_first_task timeboxing
}


logp() {


    header=$(head -n 1 log_data_personal.csv)
    #parameters_csv=(${header//,/})
    #IFS=', ' read -ra parameters_csv <<< "$header"; echo parameters_csv
    for c in $header
    do
        if [[ "$c" == "," ]]
        then
            echo comma
            break
        fi
        printf $c
    done
    val_string_all=''

    for par in $parameters_csv 
    do
        echo $par
        read input_val
        val_string_all="$val_string_all,$input_val"
    done
    echo $val_string_all >> log_data_personal.csv
}

review_projects() {
    NUM_LINES=$(cat ~/projects | wc -l)
    for i in {1..$NUM_LINES}
    do
        line_first_word=$(awk "NR==$i{print $1}" ~/projects)
        if [[ $line_first_word == "###"* ]]
        then
            break

        fi
        if [[ $line_first_word != "" ]]
        then
            echo '==========================================================================='
            echo '==========================================================================='
            echo "PROJECT: "$line_first_word
            task rc.context=none pro:$line_first_word
            echo ""
            echo ""
            echo ""
        fi
    done

}

review_someday_maybe() {
    task context sm
    tmux split-window -v -t "$pane" "watch --color -n 0,1 task"
}

iw() {
    task $(get_first_task) mod wait:1h
}

task_tag() {
    if [[ $2 =~ ^-?[0-9]+$ ]]
    then
        task "${@:2}" mod $1
    else
        task add "${@:2}" $1
    fi
}

n() {
    task_tag +next $@
}

nl() {
    task_tag +next_local $@
}

tws() {
    timew @1 shorten $@
}

main() {
    task add pro:$(awk 'NR==1' ~/main_project) +next $@
}

pas() {
    pa $@ +next
    rs
}

tss() {
    ts ss $@
}

kb() {
    ~/git/dotfiles/keyboard_config/start.sh
}

schlafen() {
    ts schlafen
    clear
    qdbus org.freedesktop.ScreenSaver /ScreenSaver Lock
    xset dpms force off
}

# Based on: https://github.com/junegunn/fzf/wiki/Examples  (cd())
function f() {
    if [[ "$#" != 0 ]]; then
        builtin cd "$@";
        return
    fi
    while true; do
        local dir_and_links=$(for e in $(echo ".." && ls -p )
                                do
                                    if [[ -d $e ]]
                                    then
                                        echo $e
                                    fi
                                done)
        local lsd=$(echo $dir_and_links | sed 's;/$;;')
        local dir="$(printf '%s\n' "${lsd[@]}" |
            fzf --reverse --preview '
                __cd_nxt="$(echo {})";
                __cd_path="$(echo $(pwd)/${__cd_nxt} | sed "s;//;/;")";
                echo $__cd_path;
                echo;
                ls -p --color=always "${__cd_path}";
        ')"
        [[ ${#dir} != 0 ]] || return 0
        builtin cd "$dir" &> /dev/null
    done
}

# Source: https://github.com/junegunn/fzf/wiki/Examples
j() {
    if [[ "$#" -ne 0 ]]; then
        cd $(autojump $@)
        return
    fi
    cd "$(autojump -s | sed '/_____/Q; s/^[0-9,.:]*\s*//' |  fzf --height 40% --reverse --inline-info)" 
}

b() {
    task add +bu +clarify +stuff $@
}

B() {
    b $@
}

ta() {
    task add $@
}

we() {
    curl wttr.in/munich
}

gu() {
    git commit $@
    git push --quiet > /dev/null &
}

time() {
    /usr/bin/time $@
}


source ~/git/bachelorarbeit/shell_functions_ba.sh
