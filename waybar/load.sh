#!/bin/bash
read -r l1 l5 l15 _ _ < /proc/loadavg
printf "L1 %5.2f   L5 %5.2f   L15 %5.2f" "$l1" "$l5" "$l15"
