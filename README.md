<div align="center">
  <h1>🚀 Dotfiles</h1>
  <p>
    <img src="https://img.shields.io/github/license/tom-doerr/dotfiles" alt="License">
    <img src="https://img.shields.io/maintenance/yes/2025" alt="Maintenance">
    <img src="https://img.shields.io/badge/platform-linux-blue" alt="Platform">
    <img src="https://img.shields.io/badge/shell-bash%20%7C%20zsh-yellow" alt="Shell">
  </p>

  <p>
    A carefully curated collection of configuration files for a powerful Linux development environment.<br>
    Optimized for productivity, customizability, and ease of use.
  </p>

  <p>
    <a href="#key-configurations">Configurations</a> •
    <a href="#installation">Installation</a> •
    <a href="#features">Features</a> •
    <a href="#customization">Customize</a> •
    <a href="#license">License</a>
  </p>
</div>

## Table of Contents

1. [Key Configurations](#key-configurations)
2. [Installation](#installation)
3. [Features](#features)
4. [Customization](#customization)
5. [License](#license)

## ⚙️ Key Configurations

| Category | Files | Description | Key Features |
|----------|-------|-------------|--------------|
| 🐚 Shell | `bashrc_custom.sh`<br>`zshrc_custom.sh`<br>`shell_functions.sh`<br>`shell_settings.sh` | Shell configurations and utilities | • Custom aliases<br>• Productivity functions<br>• Environment setup |
| 🖥️ Terminal | `kitty.conf`<br>`tmux/tmux.conf` | Terminal emulator & multiplexer | • Split panes<br>• Session management<br>• Custom keybindings |
| 🪟 Window Management | `i3/config`<br>`i3blocks.conf`<br>`picom.conf` | i3wm & compositor settings | • Tiling layouts<br>• Workspace management<br>• Window effects |
| ✏️ Text Editors | `vimrc`<br>`inputrc` | Editor configurations | • Vim plugins<br>• Custom mappings<br>• IDE features |

## 🚀 Installation

### Prerequisites
```bash
# Install required packages
sudo apt install git vim tmux i3 kitty zsh
```

### Quick Start
1. Clone this repository:
```bash
git clone https://github.com/tom-doerr/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

2. Run the installation script:
```bash
./setup.sh
```

### Manual Setup
1. Create symlinks:
```bash
# Shell
ln -s ~/.dotfiles/bashrc_custom.sh ~/.bashrc_custom
ln -s ~/.dotfiles/zshrc_custom.sh ~/.zshrc_custom

# Terminal
ln -s ~/.dotfiles/kitty.conf ~/.config/kitty/kitty.conf
ln -s ~/.dotfiles/tmux/tmux.conf ~/.tmux.conf

# Window Manager
ln -s ~/.dotfiles/i3/config ~/.config/i3/config
ln -s ~/.dotfiles/i3blocks.conf ~/.config/i3blocks/config

# Editors
ln -s ~/.dotfiles/vimrc ~/.vimrc
ln -s ~/.dotfiles/inputrc ~/.inputrc
```

2. Install plugins:
```bash
# Vim plugins
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
vim +PluginInstall +qall

# Tmux plugins
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
tmux source-file ~/.tmux.conf
```

## ✨ Features

### 🛠️ Development Tools
- **Vim Configuration** ![Vim](https://img.shields.io/badge/Editor-Vim-brightgreen)
  - Code completion
  - Syntax highlighting
  - Git integration
  - File navigation

### 🖥️ Terminal Experience
- **Tmux Setup** ![Tmux](https://img.shields.io/badge/Terminal-Tmux-blue)
  - Session persistence
  - Split panes
  - Status bar customization

### 🎨 Window Management
- **i3wm Configuration** ![i3wm](https://img.shields.io/badge/WM-i3wm-purple)
  - Tiling layouts
  - Workspace organization
  - Custom keybindings

### 🐚 Shell Environment
- **Cross-Shell Support** ![Shell](https://img.shields.io/badge/Shell-Bash%20%7C%20Zsh-yellow)
  - 100+ custom functions
  - Productivity aliases
  - Environment consistency

### 🎯 Productivity
- **Task Management** ![Tasks](https://img.shields.io/badge/Tasks-Automated-orange)
  - Quick commands
  - Custom scripts
  - Workflow automation

## Customization

To customize these configurations:

1. Fork this repository
2. Modify the config files
3. Create a new branch for your changes
4. Commit and push your changes

## License

MIT License - Feel free to use and modify these configurations

![GitHub stars](https://img.shields.io/github/stars/tom-doerr/dotfiles?style=social)
