#!/bin/bash
# ROSpider (Hiwonder hexapod) battery for waybar. Polls /ros_robot_controller/battery
# (millivolts, 3S LiPo) over ssh; prints JSON. Empty output = module hidden (robot off).
# Test the formatting without the robot:  ROSPIDER_MV=11500 ~/.config/waybar/rospider.sh
mv=${ROSPIDER_MV:-}
if [ -z "$mv" ]; then
    host=$(ssh -G rospider 2>/dev/null | awk '/^hostname /{print $2}')
    timeout 2 bash -c "</dev/tcp/${host:-rospider}/22" 2>/dev/null || exit 0   # robot off: hide quickly
    mv=$(timeout 15 ssh -o BatchMode=yes -o ConnectTimeout=3 rospider \
        "docker exec -u ubuntu -w /home/ubuntu rospider /bin/zsh -c 'source ~/.zshrc >/dev/null 2>&1; timeout 8 ros2 topic echo --once /ros_robot_controller/battery 2>/dev/null | grep -oE \"[0-9]+\" | head -1'" 2>/dev/null)
fi
case "$mv" in ''|*[!0-9]*) exit 0 ;; esac
[ "$mv" -gt 5000 ] || exit 0

# 3S LiPo discharge table (pack volts -> %), linear between points; alarm on the board ~10.0 V.
pct=$(awk -v mv="$mv" 'BEGIN {
    n=split("12600:100 12300:90 12000:75 11700:55 11400:40 11100:25 10800:15 10500:8 10000:0", t, " ");
    v=mv+0; if (v>=12600) {print 100; exit} if (v<=10000) {print 0; exit}
    for (i=1;i<n;i++) { split(t[i],a,":"); split(t[i+1],b,":");
        if (v<=a[1] && v>=b[1]) { printf "%d", b[2]+(a[2]-b[2])*(v-b[1])/(a[1]-b[1]); exit } } }')
volts=$(awk -v mv="$mv" 'BEGIN{printf "%.2f", mv/1000}')
class=ok; [ "$pct" -lt 40 ] && class=warning; [ "$pct" -lt 20 ] && class=critical
printf '{"text":"🕷 %s%%","tooltip":"ROSpider battery %s V (3S LiPo, alarm at ~10.0 V)","class":"%s","percentage":%s}\n' "$pct" "$volts" "$class" "$pct"
