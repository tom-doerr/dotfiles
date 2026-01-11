#!/bin/bash
statfile=/tmp/.waybar_cpu_stat
read -r _ user nice sys idle iowait irq softirq _ _ _ < <(grep '^cpu ' /proc/stat)
total=$((user + nice + sys + idle + iowait + irq + softirq))
idle_all=$((idle + iowait))
if [[ -f $statfile ]]; then
    read -r prev_total prev_idle < "$statfile"
    diff_total=$((total - prev_total))
    diff_idle=$((idle_all - prev_idle))
    util=$((100 * (diff_total - diff_idle) / diff_total))
    ((util < 0)) && util=0
    ((util > 100)) && util=100
else
    util=0
fi
echo "$total $idle_all" > "$statfile"
filled=$((util / 10))
empty=$((10 - filled))
bar=$(printf '█%.0s' $(seq 1 $filled 2>/dev/null))$(printf '░%.0s' $(seq 1 $empty 2>/dev/null))
echo "spark-1 CPU ${bar} ${util}% "
