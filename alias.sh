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
alias bi='task add +b inf '
alias twa='tw month 2018-01-01 - tomorrow'
alias tr1='task report1'
alias r1='task report1'
alias tc='task context '
alias id='task done $(t +bu +PENDING _ids | awk '"'"'NR==1{print $1}'"'"')'

alias ng="/usr/local/lib/node_modules/@angular/cli/bin/ng"

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

alias python='python3'
alias ipython='ipython3'
alias pip='pip3'
