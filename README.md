# Dotfiles ![GitHub](https://img.shields.io/github/license/yourusername/dotfiles) ![Maintenance](https://img.shields.io/maintenance/yes/2025)

My personal configuration files for various tools and environments. These are optimized for a Linux development workflow.

## Table of Contents

1. [Key Configurations](#key-configurations)
2. [Installation](#installation)
3. [Features](#features)
4. [Customization](#customization)
5. [License](#license)

## Key Configurations

| Category         | Files                                                                 | Description                                                                 |
|------------------|-----------------------------------------------------------------------|-----------------------------------------------------------------------------|
| Shell            | `bashrc_custom.sh`, `zshrc_custom.sh`, `shell_functions.sh`, `shell_settings.sh` | Custom shell configurations, aliases, functions and environment variables  |
| Terminal         | `kitty.conf`, `tmux/tmux.conf`                                        | Terminal emulator and multiplexer configurations                           |
| Window Management| `i3/config`, `i3blocks.conf`, `picom.conf`                            | i3 window manager, status bar and compositor settings                      |
| Text Editors     | `vimrc`, `inputrc`                                                   | Vim and readline configurations                                            |

## Installation

1. Clone this repository:
```bash
git clone https://github.com/tom-doerr/dotfiles.git ~/.dotfiles
```

2. Create symlinks:
```bash
ln -s ~/.dotfiles/vimrc ~/.vimrc
ln -s ~/.dotfiles/tmux/tmux.conf ~/.tmux.conf
# Repeat for other config files...
```

3. Install dependencies:
```bash
# Vim plugins
vim +PluginInstall +qall

# Tmux plugins
tmux source-file ~/.tmux.conf
```

## Features

- **Productivity Focused** ![Productivity](https://img.shields.io/badge/-Productivity-blueviolet)
- **Cross-Shell Compatibility** ![Shell](https://img.shields.io/badge/Shell-Bash%20%7C%20Zsh-blue)
- **Custom Shell Functions** ![Functions](https://img.shields.io/badge/Functions-100%2B-yellowgreen)
- **Theming** ![Theming](https://img.shields.io/badge/Theming-Consistent-orange)
- **Window Management** ![i3wm](https://img.shields.io/badge/Window%20Manager-i3wm-9cf)

## Customization

To customize these configurations:

1. Fork this repository
2. Modify the config files
3. Create a new branch for your changes
4. Commit and push your changes

## License

MIT License - Feel free to use and modify these configurations

![GitHub stars](https://img.shields.io/github/stars/tom-doerr/dotfiles?style=social)
