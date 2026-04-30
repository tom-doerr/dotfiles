#!/bin/bash
read -r l1 l5 l15 _ _ < /proc/loadavg
printf "L %.1f/%.1f/%.1f" "$l1" "$l5" "$l15"
