#!/bin/sh

# IPython
ln -s ~/git/dotfiles/ipython_config.py ~/.ipython/profile_default/ipython_config.py

# Taskwarrior
ln -s ~/git/dotfiles/taskrc ~/.taskrc

# VIM
ln -s ~/git/dotfiles/vimrc ~/.vimrc
mkdir ~/.config/nvim
ln -s ~/git/dotfiles/vimrc ~/.config/nvim/init.vim

# Tmux
ln -s ~/git/dotfiles/tmux/tmux.conf ~/.tmux.conf

# Bash
if grep -Fxq "source ~/git/dotfiles/bashrc_custom.sh" ~/.bashrc
then
"source ~/git/dotfiles/bashrc_custom.sh" >> ~/.bashrc
fi
