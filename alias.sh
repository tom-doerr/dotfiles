# Show battery stats
alias bat="watch 'upower -i /org/freedesktop/UPower/devices/battery_BAT0| grep -E \"time to empty|percentage\"'"

alias op='xdg-open'

alias vi='nvim'

alias print-mail='/home/tom/git/private/print_email.py'

alias t=task
alias tw=timew
alias ta='task add'
alias tat='task add due:tomorrow'
alias tatm='task add due:tomorrow+1d'
alias tb='task add wait:friday scheduled:friday +batch '
alias bu='task add +bu +clarify +stuff '
alias b='task add +bu +clarify +stuff '
alias n='task add +netsec inf '
alias e='task add +era inf '


alias ng="/usr/local/lib/node_modules/@angular/cli/bin/ng"

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
