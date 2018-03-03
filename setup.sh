#!/bin/sh

# IPython
ln -s ~/git/dotfiles/ipython_config.py ~/.ipython/profile_default/ipython_config.py

# Taskwarrior
ln -s ~/git/dotfiles/taskrc ~/.taskrc

# VIM
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
ln -s ~/git/dotfiles/vimrc ~/.vimrc
mkdir ~/.config/nvim
ln -s ~/git/dotfiles/vimrc ~/.config/nvim/init.vim

# Tmux
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
ln -s ~/git/dotfiles/tmux/tmux.conf ~/.tmux.conf

# Bash
if grep -Fxq "source ~/git/dotfiles/bashrc_custom.sh" ~/.bashrc
then
"source ~/git/dotfiles/bashrc_custom.sh" >> ~/.bashrc
fi
