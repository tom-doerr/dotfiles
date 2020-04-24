#!/bin/bash

apt install -y wget python3-pip zsh

# IPython
pip3 install ipython
mkdir -p ~/.ipython/profile_default
ln -s ~/git/dotfiles/ipython_config.py ~/.ipython/profile_default/ipython_config.py

# Inputrc
ln -s ~/git/dotfiles/inputrc ~/.inputrc

# VIM
apt install -y neovim
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
ln -s ~/git/dotfiles/vimrc ~/.vimrc
mkdir ~/.config/nvim
ln -s ~/git/dotfiles/vimrc ~/.config/nvim/init.vim
cd ~/.vim/bundle/vimproc.vim && make

# FZF
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install

# Autojump
sudo apt install -y autojump

# Bash
if ! grep -Fxq "source ~/git/dotfiles/bashrc_custom.sh" ~/.bashrc
then
echo "source ~/git/dotfiles/bashrc_custom.sh" >> ~/.bashrc
fi

#Zsh
sudo apt install -y zsh
wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh
cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc
if ! grep -Fxq "source ~/git/dotfiles/zshrc_custom.sh" ~/.zshrc
then
echo "source ~/git/dotfiles/zshrc_custom.sh" >> ~/.zshrc
fi
cd ~/.oh-my-zsh/custom/plugins
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git
cd
git clone https://github.com/supercrabtree/k $ZSH_CUSTOM/plugins/k
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh

if [[ "$1" != "basic" ]]
then
    # Taskwarrior
    ln -s ~/Nextcloud/sonstiges/task ~/.task

    if ! grep -Fxq "include ~/git/dotfiles/taskrc_custom" ~/.taskrc
    then
    echo "include ~/git/dotfiles/taskrc_custom" >> ~/.taskrc
    fi

    # GTD
    ln -s Nextcloud/documents/gtd/general-references
    ln -s Nextcloud/documents/gtd/incubation/someday-maybe
    ln -s Nextcloud/documents/gtd/projects
    ln -s Nextcloud/documents/gtd/project-support-material

    # Timewarrior
    ln -s ~/Nextcloud/sonstiges/timewarrior ~/.timewarrior
    cp ext/on-modify.timewarrior ~/.task/hooks/
    chmod +x ~/.task/hooks/on-modify.timewarrior


    # SSH
    ln -s ~/git/private/ssh_config ~/.ssh/config
    sudo apt-get -y install keychain

    # KDE
    ln -s ~/git/dotfiles/kglobalshortcutsrc ~/.config/klglobalshortcutsrc

    # Hueadm
    ln -s ~/git/private/hueadm.json ~/.hueadm.json
fi
