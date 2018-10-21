ATHAME_ENABLED=0
export ATHAME_ENABLED

ATHAME_SHOW_MODE=0
export ATHAME_SHOW_MODE

ATHAME_VIM_PERSIST=1
export ATHAME_VIM_PERSIST

ATHAME_TEST_RC=~/.athamerc
export ATHAME_TEST_RC

set -o vi
setopt EXTENDED_GLOB

# Set history file size
HISTSIZE=1000000
HISTFILESIZE=2000000


bindkey '^R' history-incremental-search-backward

DISABLE_AUTO_UPDATE=true

export neowatch_page_number_file_path='/var/tmp/neowatch_page_number_file'

source ~/git/dotfiles/shell_functions.sh
source ~/git/dotfiles/alias.sh

