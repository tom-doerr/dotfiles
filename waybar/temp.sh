#!/bin/bash
nvme=$(sensors | grep Composite | head -1 | awk '{print $2}' | tr -d '+C°')
fan=$(sensors | grep fan1 | awk '{print $2}')
echo "NVMe ${nvme}° FAN ${fan}"
