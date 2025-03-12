# If you come from bash you might have to change your $PATH.
# Startup timing with sections
typeset -F START_TIME=$SECONDS

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
if [[ "$HOST" == "desktop-20" ]] || [[ "$HOST" == "tom-Desktop-18" ]] || [[ "$HOST" == "desktop-20-3" ]]
then
    ZSH_THEME="robbyrussell"
else
    ZSH_THEME="fishy"
fi

# Set list of themes to load
# Setting this variable when ZSH_THEME=random
# cause zsh load theme from this variable instead of
# looking in ~/.oh-my-zsh/themes/
# An empty array have no effect
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
  colored-man-pages
  last-working-dir
  zsh_codex
)

typeset -F OMZ_START=$SECONDS
source $ZSH/oh-my-zsh.sh
echo "oh-my-zsh loaded in $(($SECONDS - $OMZ_START))s"

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

ATHAME_ENABLED=0
export ATHAME_ENABLED

ATHAME_SHOW_MODE=0
export ATHAME_SHOW_MODE

ATHAME_VIM_PERSIST=1
export ATHAME_VIM_PERSIST

ATHAME_TEST_RC=~/.athamerc
export ATHAME_TEST_RC

KEYTIMEOUT=1
export KEYTIMEOUT

set -o vi
setopt EXTENDED_GLOB

# Set history file size
HISTSIZE=1000000000
export HISTSIZE

HISTFILESIZE=2000000000
export HISTFILESIZE

enter_j(){
    j
    echo
    echo $ ls $(pwd)
    ls
    zle reset-prompt
}

enter_j_z_fzf() {
    cd $(z -l . | fzf  --nth 2.. --tac --no-sort | awk '{$1=""; print $0}')
    zle reset-prompt
}


enter_f(){
    f
    echo
    echo
    echo $ ls $(pwd)
    ls
    zle reset-prompt
}

clear2(){
    clear
    zle reset-prompt
}

vim_history(){
    nvim -c ':History<CR>'
}

update_display_variable(){
    $(tmux show-environment | grep '^DISPLAY=')
}


bindkey '^R' history-incremental-search-backward
bindkey '^K' fzf-history-widget

zle -N enter_j_z_fzf
bindkey '^[j' enter_j_z_fzf
bindkey '^j' enter_j_z_fzf

zle -N enter_f
bindkey '^[f' enter_f
bindkey '^f' enter_f

zle -N clear2
bindkey '^[l' clear2

bindkey '^P' expand-or-complete-prefix

zle -N fzf-file-widget
bindkey '^[a' fzf-file-widget
bindkey '^a' fzf-file-widget

zle -N vim_history
bindkey '^[s' vim_history
bindkey '^s' vim_history

zle -N ranger_cd
bindkey '^[o' ranger_cd

eval "$(lua ~/git/z.lua/z.lua --init zsh)"

export neowatch_page_number_file_path='/var/tmp/neowatch_page_number_file'
export PATH="$HOME/anaconda3/bin:$PATH"
export PATH="$PATH:$HOME/bin"

source /usr/share/autojump/autojump.sh
source ~/git/dotfiles/shell_functions.sh
source ~/git/dotfiles/alias.sh
source ~/git/dotfiles/shell_settings.sh

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
source  ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

zle -N t
bindkey '^t' t

export DISABLE_AUTO_UPDATE="true"

#if [[ -n $TMUX ]]
#then
#    add-zsh-hook precmd update_display_variable
#fi


# Comment out the old PYTHONPATH export
# export PYTHONPATH="${PYTHONPATH}:/home/tom/.local/lib/python3.8/site-packages"
# Instead, only add it if we're using Python 3.8
if python3 -c "import sys; exit(0 if sys.version_info.major == 3 and sys.version_info.minor == 8 else 1)" 2>/dev/null; then
    export PYTHONPATH="${PYTHONPATH}:/home/tom/.local/lib/python3.8/site-packages"
fi

[ -f ~/.zprofile ] || echo "No ~/.zprofile found. You might want to create a symlink using 'ln -s .profile .zprofile'."

if [[ $1 == eval ]]
then
    "$@"
    set --
fi


# Change the color of comments in ZSH to grey.
ZSH_HIGHLIGHT_STYLES[comment]='none'

bindkey '^X' create_completion

#alias lf='*(om[1])'
#lf() { echo *(om[1]) }
# Show detailed load times
echo "${(l.$COLUMNS..-.)}"
echo "Total zshrc load time: $(($SECONDS - $START_TIME))s"
