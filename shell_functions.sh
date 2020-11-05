# Extract files with ex command
source ~/git/private/private_shell_functions.sh

ex ()
{
  if [ -f $1 ] ; then
    case $1 in
      *.tar.bz2)   tar xjf $1   ;;
      *.tar.gz)    tar xzf $1   ;;
      *.tar.lrz)   lrztar -d $1 ;; 
      *.bz2)       bunzip2 $1   ;;
      *.rar)       unrar x $1   ;;
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

end_taskwarrior_timewarrior() {
    task_output="$(task +ACTIVE done 2>&1)"
    if [[ "$task_output" = *"No tasks specified."* ]] 
    then
        timew stop
    else
        echo "$task_output"
    fi
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

get_active_task_data() {
    grep ' start:"[0-9]*" ' ~/.task/pending.data
}

set_activity() {
    qdbus org.kde.ActivityManager /ActivityManager/Activities SetCurrentActivity "$1"
}

switch_to_home_activity() {
        set_activity 625aba1d-ac94-49b5-91ee-567a86d24fe5
}

trigger_commands_for_activity() {
    if [[ $1 == *"bettzeit"* ]]
    then
        hueadm light 6 off
        hueadm light 7 off
    elif [[ $1 == *"Fruehstuecke"* ]]
    then
        hueadm light 6 on
        hueadm light 7 on
    elif [[ $1 == *"Arbeite an Fitness"* ]]
    then
        hueadm light 6 off
        hueadm light 7 off
    fi
}

ts() {
    if [[ $1 == "" ]] 
    then
        end_taskwarrior_timewarrior
        task context h
        trigger_commands_for_activity
    elif [[ $1 =~ ^-?[0-9]+$ ]]
    then
        uuid=$(task $1 _uuid)
        end_taskwarrior_timewarrior
        task start $uuid
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
        stop_taskwarrior_timewarrior
        if [[ "$(task _context)" == *$(printf "$1\n")* ]]
        then
            tc $1
        fi
        tags_to_add="$(~/git/scripts/timew_add_tags.py $@)"
        trigger_commands_for_activity "$@""$tags_to_add"
        eval "timew start $tags_to_add $@"
    fi
}


at() {
    tags_to_add="$(~/git/scripts/timew_add_tags.py $@)"
    timew stop && eval "timew cont && timew @1 tag $tags_to_add $@"
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

execute_for_currently_active_tasks() {
    taskwarrior_command_to_execute=$1
    task rc.context=none +ACTIVE $taskwarrior_command_to_execute
}

get_uuids_currently_active_tasks() {
    task rc.context=none +ACTIVE _uuid
}

td() {
    execute_for_id_argument_else_fzf "task done" "$@"
    #if [[ $1 == "" ]]
    #then
    #    current_task_tags=$(task _get $(task rc.context=none +ACTIVE _uuid).tags)
    #    task rc.context=none +ACTIVE done
    #    tags_without_next_twt=${current_task_tags//next_twt/}
    #    eval "tw start ${tags_without_next_twt//,/ }"
    #else
    #    task done $@
    #fi
}

pa() {
    if [[ "$(task all +ACTIVE)" != "" ]]
    then
        description_string="$(echo $@ | awk '{split($0,a,"-"); print a[1]}')"
        modifications_string="$(echo $@ | awk '{split($0,a,"-"); print a[2]}')"
        task $(t +ACTIVE _uuid) duplicate -clarify description:$description_string $modifications_string
    else
        current_taskwarrior_context="$(get_current_taskwarrior_context)"
        task add $1 +"$current_taskwarrior_context"
    fi

}

rb() {
    tmux split-window -v -t "$pane" "watch --color -n 0,1 task review_bucket_items"
    while true
    do
        read command
    if [[ $command == "" ]]
    then
        bucket_item_done
    else
        eval $command
    fi
    done
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
    if [[ $2 =~ ^-?([0-9]|,)+$ ]]
    then
        toggle_tag $1 "${@:2}"
    else
        task add "${@:2}" '+'$1
    fi
}

toggle_tag() {
    tag=$1
    task_ids=${@:2}
    for task_id in $(echo ${task_ids//,/ })
    do
        task_tags=$(task _get "$task_id".tags)
        if [[ $task_tags =~ $tag ]]
        then
            task $task_id modify -"$tag"
        else
            task $task_id modify +"$tag"
        fi
    done
}

execute_for_id_argument_else_fzf() {
    command_to_execute="$1"
    command_arguments="${@:2}"
    if [[ "$command_arguments" != "" ]]
    then
        eval "$command_to_execute $command_arguments"
    else
        id="$(get_task_id_fzf)"
        if [[ ! -z "$id" ]]
        then
            eval "$command_to_execute $id"
        fi
    fi
}

st() {
    execute_for_id_argument_else_fzf "ts" "$@"
}

n() {
    execute_for_id_argument_else_fzf "task_tag next" "$@"
}

get_task_id_fzf() {
    task report1 | 
        head -n-2 | 
        tail -n+3 | 
        fzf --ansi | 
        awk '{print $1}'
}

nl() {
    execute_for_id_argument_else_fzf "task_tag next_local" "$@"
}

tws() {
    time_length="$1"
    tags=${@:2}
    ts
    timew @1 shorten $time_length
    if [[ "$tags" != "" ]]
    then
        timestamp_start=$(date --date "$time_length ago" --utc "+%Y-%m-%dT%H:%M:%SZ")
        eval "ts $timestamp_start $tags"
    fi
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

turn_all_lights_off() {
    bash -c '
    hue_lights="7 6 4" 
    for e in $hue_lights 
    do                    
        hueadm light $e off 
    done                    
    '
}

schlafen() {
    ts schlafen
    turn_all_lights_off
    clear
    sstop
    xset dpms force off
}

# Based on: https://github.com/junegunn/fzf/wiki/Examples  (cd())
f() {
    if [[ "$#" != 0 ]]; then
        builtin cd "$@";
        return
    fi
    while true; do
        local dir_and_links=$(for e in $(echo ".." && ls -pA )
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
    curl v2.wttr.in/garching_bei_muenchen | head -31
}

gu() {
    git commit $@
    git push --quiet > /dev/null &
}

sd() {
    if [[ $DISPLAY == ":0" ]]
    then
        DISPLAY='localhost:10.0'
    elif [[ $DISPLAY =~ localhost:1.*\.0 ]]
    then
        DISPLAY=':0'
    fi
    echo $DISPLAY
}

h() {
    task report1
}

ww() {
    nvim -c 'VimwikiIndex'
}

add_pro() {
    projects_filename=~/projects.wiki
    echo "" >> $projects_filename
    echo "== $1 | pro:$1 ==" >> $projects_filename
    echo "" >> $projects_filename
}

ai() {
    b ai $@ 
}

tai() {
    ta +ai $@
}

com() {
    task all rc.context=none end.after:$(date --date '5 hours ago' +%Y-%m-%d)T05:00:00 +COMPLETED -bu $1
}

hcon() {
    hueadm light 6 on
}

hcoff() {
    hueadm light 6 off
}

toggle_light() {
    if [[ $(hueadm light $1) == *"on: true"* ]] 
    then
        hueadm light $1 off
    else
        hueadm light $1 on
        hueadm light $1 \=100% &> /dev/null; true
    fi
}

hc() {
    toggle_light 6
}

hw() {
    toggle_light 4
}

hm() {
    toggle_light 7
}

ha() {
    toggle_light 4
    toggle_light 6
    toggle_light 7
}

bucket_item_done() {
    task done $(get_first_task '+bu +PENDING')
}

splay() {
    spotifycli --client $SPOTIFY_DBUS_CLIENT --play
}

spause() {
    spotifycli --client $SPOTIFY_DBUS_CLIENT --pause
}

sstop() {
    spause
}

snext() {
    spotifycli --client $SPOTIFY_DBUS_CLIENT --next
}

sprev() {
    spotifycli --client $SPOTIFY_DBUS_CLIENT --prev
}

ntest() {
    tests_path=~/git/bachelorarbeit/tests 
    cd $tests_path
    f=$(find)
    last_test=$(echo ${f//\.\//} | sort -n | tail -n 1)
    new_test_name=$(expr $last_test + 1)
    if [[ $1 == "" ]]
    then
        cp template $new_test_name
    else
        cp $1 $new_test_name
    fi
    cd -
    nvim $tests_path/$new_test_name
}

nh() {
    task add $@ +h +next
}

kido() {
    container_name="$(docker ps --no-trunc | ag output_audio/"$1"/ | awk 'END {print $NF}')"
    docker kill "$container_name"
}

bms() {
    bm status
}

# Energy logging
add_energy_level_entry_log() {
    echo "$(date +"%s"), $1" >> ~/Nextcloud/documents/energy_log
}

ej() {
    add_energy_level_entry_log 0
}
    
ek() {
    add_energy_level_entry_log 1
}

el() {
    add_energy_level_entry_log 2
}

gkii() {
    ta +gki inf $@
}

vwli() {
    ta +vwl inf $@
}

gmmi() {
    ta +gmm inf $@
}

mli() {
    ta +ml inf $@
}

idli() {
    ta +idl inf $@
}

nlpi() {
    ta +nlp inf $@
}

tsf() {
    eval 'echo "   "; timew su $(date --date "5 hours ago" +%Y-%m-%d)T05:00:00 - tomorrow '$1' | tail -2 | head -1 | { read first rest; echo $first; }'
}

tsfa() {
    bash -c '
        source ~/git/dotfiles/shell_functions.sh
        TAGS="prof idl vwl nlp ml gki gmm"
        for e in $TAGS
        do
            tsf $e
            echo $e
        done
    '
}

tabc() {
    xinput map-to-output 13 DP-2
}

lock() {
    qdbus org.freedesktop.ScreenSaver /ScreenSaver Lock
    xset dpms force off
}

hms_to_hours() {
    hours_comma=$(echo "$1" | awk -F: '{ print (($1 * 3600) + ($2 * 60) + $3) / 3600 }')
    hours_dot=${hours_comma/,/.}
    echo $hours_dot
}

leaving() {
    sleep 30
    turn_all_lights_off
    spause
}

# based on: https://github.com/ranger/ranger/blob/master/examples/bash_automatic_cd.sh
ranger_cd() {
    tempfile="$(mktemp -t tmp.XXXXXX)"
    ranger --choosedir="$tempfile" "${@:-$(pwd)}"
    test -f "$tempfile" &&
    if [ "$(cat -- "$tempfile")" != "$(echo -n `pwd`)" ]; then
        cd -- "$(cat "$tempfile")"
    fi
    rm -f -- "$tempfile"
}

r() {
    ranger_cd
}

sst() {
    spause
}

#st() {
#    spause
#}

sp() {
    splay
}

sn() {
    snext
}

set_schedule_to_time() {
    schedule_id=$1
    time_hms=$2
    hueadm modify-schedule $schedule_id "status=enabled" "localtime=$(date --date '13 hours' +%Y-%m-%d)T"$time_hms
}

get_time_hms_from_input() {
    input_time=$1
    offset=$2
    date -d "$input_time $offset" +"%H:%M:%S"
}

hwa() {
    time=$1
    set_schedule_to_time 5 $(get_time_hms_from_input $time "30min ago")
    set_schedule_to_time 11 $(get_time_hms_from_input $time)
}

hwas() {
    time=$1
    set_schedule_to_time 5 $(get_time_hms_from_input $time "30min ago")
    hueadm modify-schedule 11 "status=disabled"
}

v() {
    sleep_time_min=$1
    if [[ "$sleep_time_min" == "" ]]
    then
        btimem_val=$(btimem)
        vtimem_val=$(vtimem)
        min_val=$(printf $btimem_val'\n'$vtimem_val'\n' | sort -g | head -n 1) 
        printf $min_val'\n\n'
        sleep_time_sec=$(($min_val * 60))
    else
        sleep_time_sec=$(( 60 * $sleep_time_min ))
    fi
    at video break
    sstop
    timeout "$sleep_time_sec"s zsh -c read
    telegram-send "Back to work! :)"
    rt video break
}


# source: https://faq.i3wm.org/question/6200/obtain-info-on-current-workspace-etc.1.html
get_i3_workspace_id() {
    i3-msg -t get_workspaces \
  | jq '.[] | select(.focused==true).name' \
  | cut -d"\"" -f2
}

toggle_workspace_99() {
    if [[ $(get_i3_workspace_id) == "99" ]]
    then
        i3-msg workspace prev
    else
        i3-msg workspace 99
    fi
}

t() {
    if [[ $@ == "" ]]
    then
        ~/git/taskwarrior-fzf/taskfzf report1
    else
        task $@
    fi
}

ve() {
    python_version=$1
    if [[ ! $python_version ]]
    then
        python_version=3.8

    fi
    if [[ ! $VIRTUAL_ENV ]]
    then
        export PYTHONPATH=""
        if [ ! -d venv ]
        then 
            virtualenv -p python"$python_version" venv
            source venv/bin/activate
            pip install ipython
            pip install neovim
            if [ -f requirements.txt ]
            then
                pip install -r requirements.txt
            fi
        else
            source venv/bin/activate
        fi
    else
        deactivate
    fi
}

mark() {
    at mark
    sleep 1
    rt mark
}

get_time_h_day() {
    hms_to_hours $(timew su $1 | tail -2 | head -1 | { read first rest; echo $first; })
}

remaining_time() {
    tag=$1
    prof_tag_ratio=$2
    TIME_TAGS_TO_REMOVE_FROM_CALCULATION=("schlafen")
    time_tag=$(get_time_h_day $tag)
    time_spent_sleeping=$(get_time_h_day "schlafen")
    time_to_remove=$time_tag
    for e in $TIME_TAGS_TO_REMOVE_FROM_CALCULATION
    do
        time_spent_on_e=$(get_time_h_day $e)
        time_to_remove=$(($time_to_remove + $time_spent_on_e))
    done
    if [[ $tag == "break" ]]
    then
        offset_time=0
        time_obj=$(get_time_h_day obj)
    elif [[ $tag == "video" ]]
    then
        offset_time=0.25
        time_obj=$(get_time_h_day obj)
    fi
    remaining_break_time_min=$((((($time_obj - $time_to_remove) / $prof_tag_ratio) \
        - $time_tag + $offset_time) * 60))
    echo $remaining_break_time_min
}

btime() {
    remaining_time break 5
}

vtime() {
    remaining_time video 5
}

round_down() {
    input_float=$1
    echo $input_float | awk '{print int($1)}'
}

btimem() {
    round_down $(btime)
}

vtimem() {
    round_down $(vtime)
}

auto_continue_no_more_break() {
    while true
    do
        read -t 1 && break
        [[ " "$(timew)" " =~ " break " ]] || break
    done
}

bk() {
    printf $(btimem)'\n\n'
    at break
    spause
    auto_continue_no_more_break
    rt break
    true
}

bt() { 
    btime 
}
vt() { 
    vtime 
}

disk-usage-analyzer() {
    ncdu
}

get_current_taskwarrior_context() {
    task context show | awk '{print substr($2, 2, length($2)-2)}'
}

# Adds a task to a project with the current context as a tag.
pc() {
    project="$1"
    task_string="${@:2}"
    current_taskwarrior_context="$(get_current_taskwarrior_context)"
    if [[ "$current_taskwarrior_context" == "h" ]]
    then
        tag_to_add=""
    else
        tag_to_add=+"$current_taskwarrior_context"
    fi
    eval "task add pro:$current_taskwarrior_context.$project\
        $task_string $tag_to_add"
}

del() {
    if [[ $1 =~ ^[0-9]+$ ]]
    then
        task_ids="$1"
        task delete $task_ids
    elif [[ "$1" != "" ]]
    then
        tracking_tags=$1
        ts $tracking_tags
    else
        active_tasks=$(get_uuids_currently_active_tasks)
        execute_for_id_argument_else_fzf "task delete" "$active_tasks"
    fi
}

get_arc_size() {
    awk '/^size/ { print  $3 / 1073741824 }' < /proc/spl/kstat/zfs/arcstats

}

watch_arc_size() {
    while true
    do
        get_arc_size
        sleep 1
    done
}

fa() {
    find | ag $@
}

dox() {
    docker run \
    -it \
    --rm \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v ~/.Xauthority:/home/root/.Xauthority \
    --env DISPLAY \
    $@
}

focus() {
    timew_focus_tag="$1"
    hours_to_focus=$2
    [[ $hours_to_focus == "" ]] && hours_to_focus=2
    tmux split-window -v
    timestamp_start=$(date +%s)
    seconds_to_focus=$(( $hours_to_focus * 3600 ))
    last_check_tag_not_in_time_tags_string=false
    while true
    do
        timestamp_current=$(date +%s)
        seconds_passed=$(( $timestamp_current - $timestamp_start ))
        (( $seconds_passed > $seconds_to_focus )) && break
        time_tags_string=" $(timew | head -n1) "
        if [[ ! "$time_tags_string" =~ " $timew_focus_tag " ]]
        then
            if [[ $last_check_tag_not_in_time_tags_string == false ]]
            then
                last_check_tag_not_in_time_tags_string=true
            else
                telegram-send "Please continue working on '$timew_focus_tag' :)"
            fi
            sleep 4
        else
            last_check_tag_not_in_time_tags_string=false
        fi
        if [[ "$time_tags_string" =~ " video " ]]
        then
            telegram-send "Please don't watch videos during focus time :)"
            sleep 4
        fi
        remaining_time_in_hours=$(echo "scale=4; ($seconds_to_focus - $seconds_passed) / 3600" | bc)
        clear
        printf "\n\n\n\n\n\n             Focus on $timew_focus_tag %.4f\n" $remaining_time_in_hours
        sleep 1
    done
    clear
    telegram-send "Focus time over :)"
}

tt() {
    echo btime: $(btime)
    echo vtime: $(vtime)
}


wd() {
    nvim -c 'VimwikiDiaryIndex'
}

plot() {
    plot_data=$1
    color=$2
    [ -v color ] && color='violet'
    echo "$plot_data" | gnuplot -p -e "set terminal dumb; plot '<cat' with lines"
}


get_last_clone_stats() {
    output_metric=$1
    for e in audio_adversarial_examples TecoGAN commonroad-docker commonroad_batch_processing i3_workspace_toggle DeepSpeech
do
        echo $e
        gt_output="$(gt $e Nextcloud/documents/github_traffic_stats)"
        if [[ $output_metric == 'totals' ]]
        then
            echo $gt_output | grep 'Git clones' -A 2 | awk 'END {print}'
        else
        echo $gt_output | grep 'Referring sites' -B 2 | awk 'NR == 1'
        fi
        echo
done
}


wa() {
    wait_time=$1
    id="$(get_task_id_fzf)"
    task $id mod wait:$wait_time

}

wad() {
    wa 1d
}

waw() {
    wa 1w
}


ca() {
    current_taskwarrior_context="$(get_current_taskwarrior_context)"
    task add $1 +"$current_taskwarrior_context"

}


op() {
    xdg-open $@ &
    disown
}

hs() {
    hm
    hw
}

check_sites() {
    brave-browser --new-window https://dl.acm.org/doi/10.1145/3385003.3410921
    sleep 0.1
    brave-browser https://github.com/tom-doerr
    brave-browser https://hub.docker.com/u/tomdoerr
    brave-browser https://stackexchange.com/users/8102914/user6105651\?tab\=accounts
}


track_time_focus() {
counter=0
data_in_seconds=''
data_in_minutes=''
time_started_to_focus=$(date +%s)
while true
do
        clear
        time_focused_seconds=$(( $(date +%s) - $time_started_to_focus ))
        time_focused_minutes=$(bc <<< "scale=2; $time_focused_seconds / 60" )
        data_in_seconds="$data_in_seconds""\n$counter, $time_focused_seconds"
        data_in_minutes="$data_in_minutes""\n$counter, $time_focused_minutes"
        counter=$(( counter + 1 ))
        plot $data_in_minutes 2>/dev/null
        echo "Minutes since last focused: $time_focused_minutes"
        time_started_to_focus=$(date +%s)
        read
done
}

