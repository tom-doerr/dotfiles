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

choose_activity() {
    if [[ $1 == *"ai"* ]]
    then
        set_activity a82a5cd2-bd0a-4c51-b5a7-5c1e1e3a06cd
    elif [[ $1 == *"gmm"* ]]
    then
        set_activity 28de45b9-7f38-42b5-a689-22d1a9ff063d
    elif [[ $1 == *"gki"* ]]
    then
        set_activity 3832cd48-8acb-4153-9d89-73d9efb5b0a4
    elif [[ $1 == *"idl"* ]]
    then
        set_activity 8a7b6ae5-0966-41bc-9499-8a05624f5d5b
    elif [[ $1 == *"ml"* ]]
    then
        set_activity 2abbc89b-7206-4f18-932b-b2d8c004f0d5
    elif [[ $1 == *"nlp"* ]]
    then
        set_activity 3248cc70-ced4-4bfc-b2ef-9d7f62563f40
    elif [[ $1 == *"vwl"* ]]
    then
        set_activity 4c9939ec-01e1-4833-ab25-3bf5a4f5e35b
    elif [[ $1 == *"uni"* ]]
    then
        set_activity 77f6ab1e-fb44-4e21-919b-4c93347be591
    elif [[ $1 == *"bettzeit"* ]]
    then
        hueadm light 6 off
        switch_to_home_activity
    else
        switch_to_home_activity
    fi
}

ts() {
    if [[ $1 == "" ]] 
    then
        end_taskwarrior_timewarrior
        task context h
        choose_activity
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
        choose_activity "$@""$tags_to_add"
        eval "timew start $tags_to_add $@"
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
        current_task_tags=$(task _get $(task rc.context=none +ACTIVE _uuid).tags)
        task rc.context=none +ACTIVE done
        tags_without_next_twt=${current_task_tags//next_twt/}
        eval "tw start ${tags_without_next_twt//,/ }"
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
    bash -c '
    hue_lights="4 6" 
    for e in $hue_lights 
    do                    
        hueadm light $e off 
    done                    
    '
    clear
    qdbus org.freedesktop.ScreenSaver /ScreenSaver Lock
    while true
    do
        xset dpms force off
        sleep 10;
    done
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
    task end.after:today+5h completed
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

ha() {
    toggle_light 4
    toggle_light 6
}

bucket_item_done() {
    task done $(get_first_task '+bu +PENDING')
}

splay() {
    spotifycli --play
}

spause() {
    spotifycli --pause
}

sstop() {
    spause
}

snext() {
    spotifycli --next
}

sprev() {
    spotifycli --prev
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

gs() {
    ~/git/scripts/goal_status_time.py
}

tabc() {
    xinput map-to-output 13 DP-2
}

lock() {
    qdbus org.freedesktop.ScreenSaver /ScreenSaver Lock
    xset dpms force off
}

