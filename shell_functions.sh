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


function stop_taskwarrior_timewarrior() {
        if [[ "$(task +ACTIVE 2>&1)" = *"No matches."* ]] 
        then
            timew stop
        else
            timew stop
            task +ACTIVE done
        fi
}

function ts_start_task() {
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
        ts_start_task $uuid
    elif [[ $1 = "stop" ]]
    then
        uuids=$(task +ACTIVE _uuid)
        task $uuids stop
    else
        stop_taskwarrior_timewarrior
        timew start "$@"
    fi
}

function at() {
    timew stop && timew cont && timew @1 tag $@
}

function rt() {
    timew stop && timew cont && timew @1 untag $@
}

function tn() {
    if [[timew get dom.active.tag.1 == $
}



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
    if [[ $1 = '' ]]
    then
        freq=30
    else
        freq=$1
    fi

        ~/git/scripts/neowatch timew :color week

}

function swatch() {
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

function td() {
    if [[ $1 == "" ]]
    then
        rt "$(t _get $(t +ACTIVE _uuid).description)"
    else
        task done $@
    fi
}

function pa() {
    description_string="$@"
    task $(t +ACTIVE _uuid) duplicate description:$description_string
}

function rb() {
    tmux split-window -v -t "$pane" "watch --color -n 0,1 task review_bucket_items"
}

function sm() {
    task $@ ls >> someday-maybe 
    task $@ delete
}

function np() {
    current_page=$(cat $neowatch_page_number_file_path)
    let "current_page += 1"
    echo $current_page > $neowatch_page_number_file_path
}

function pp() {
    current_page=$(cat $neowatch_page_number_file_path)
    if [[ $current_page > 0 ]]
    then
        let "current_page -= 1"
    fi
    echo $current_page > $neowatch_page_number_file_path
}

function ggp() {
    current_page=1
    echo $current_page > $neowatch_page_number_file_path
}



function start_first_task() {
    echo 'task '$@
    stop_taskwarrior_timewarrior
    number_top_task_r1=$(bash -c 'task '$@' | awk '"'"'NR==3{print $1}'"'"'')    
    number_top_task_r1_nocolor=$(echo $number_top_task_r1 | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g")
    if [[ $number_top_task_r1_nocolor == '' ]]
    then 
        number_top_task_r1=$(bash -c 'task '$@' | awk '"'"'NR==3{print $2}'"'"'')    
        number_top_task_r1_nocolor=$(echo $number_top_task_r1 | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g")
    fi
    ts $number_top_task_r1_nocolor
}

function rs() {
    start_first_task report1
}

function ds() {
    start_first_task timeboxing
}


function logp() {


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

function next() {
    task add starte \"$(task _get $1.description)\" +next
    task mod $1 +next
}

review_projects() {
    NUM_LINES=$(cat ~/projects.md | wc -l)
    for i in {1..$NUM_LINES}
    do
        line_first_word=$(awk "NR==$i{print $1}" ~/projects.md)
        if [[ $line_first_word == "###"* ]]
        then
            break

        fi
        if [[ $line_first_word != "" ]]
        then
            echo "PROJECT: "$line_first_word
            task rc.context=none pro:$line_first_word
            echo ""
        fi

    done

}
