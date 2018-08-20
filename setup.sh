#!/bin/sh

# IPython
ln -s ~/git/dotfiles/ipython_config.py ~/.ipython/profile_default/ipython_config.py

# Taskwarrior
ln -s ~/Nextcloud/sonstiges/task ~/.task

if ! grep -Fxq "include ~/git/dotfiles/taskrc_custom" ~/.taskrc
then
echo "include ~/git/dotfiles/taskrc_custom" >> ~/.taskrc
fi


# GTD
ln -s Nextcloud/documents/gtd/general-references
ln -s Nextcloud/documents/gtd/incubation/someday-maybe
ln -s Nextcloud/documents/gtd/incubation/tickler



# Timewarrior
ln -s ~/Nextcloud/sonstiges/timewarrior ~/.timewarrior
cp ext/on-modify.timewarrior ~/.task/hooks/
chmod +x ~/.task/hooks/on-modify.timewarrior

# VIM
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
ln -s ~/git/dotfiles/vimrc ~/.vimrc
mkdir ~/.config/nvim
ln -s ~/git/dotfiles/vimrc ~/.config/nvim/init.vim
cd ~/.vim/bundle/vimproc.vim && make

# Tmux
sudo apt-get install xclip
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
ln -s ~/git/dotfiles/tmux/tmux.conf ~/.tmux.conf
sudo apt-get install fonts-powerline

# Bash
if ! grep -Fxq "source ~/git/dotfiles/bashrc_custom.sh" ~/.bashrc
then
echo "source ~/git/dotfiles/bashrc_custom.sh" >> ~/.bashrc
fi

#Zsh
sudo apt install zsh
wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh
cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc
if ! grep -Fxq "source ~/git/dotfiles/zshrc_custom.sh" ~/.zshrc
then
echo "source ~/git/dotfiles/zshrc_custom.sh" >> ~/.zshrc
fi
