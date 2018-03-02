#!/bin/sh

ln -s ~/git/dotfiles/ipython_config.py ~/.ipython/profile_default/ipython_config.py
ln -s ~/git/dotfiles/taskrc ~/.taskrc
ln -s ~/git/dotfiles/vimrc ~/.vimrc
mkdir ~/.config/nvim
ln -s ~/git/dotfiles/vimrc ~/.config/nvim/init.vim
ln -s ~/git/dotfiles/tmux/tmux.conf ~/.tmux.conf
