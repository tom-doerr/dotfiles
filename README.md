# Dotfiles

My personal configuration files for various tools and environments. These are optimized for a Linux development workflow.

## Key Configurations

### Shell
- `bashrc_custom.sh`: Custom bash configuration with aliases and functions
- `zshrc_custom.sh`: Zsh configuration with plugins, keybindings and custom functions
- `shell_functions.sh`: Shared shell functions for both bash and zsh
- `shell_settings.sh`: Environment variables and startup settings

### Terminal
- `kitty.conf`: Kitty terminal emulator configuration
- `tmux/tmux.conf`: Tmux configuration with keybindings and plugins

### Window Management
- `i3/config`: i3 window manager configuration
- `i3blocks.conf`: i3 status bar configuration
- `picom.conf`: Compositor configuration for window effects

### Text Editors
- `vimrc`: Vim configuration with plugins and keybindings
- `inputrc`: Readline configuration for command line editing

## Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles
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

- **Productivity Focused**: Optimized keybindings and workflows
- **Cross-Shell Compatibility**: Works with both bash and zsh
- **Custom Shell Functions**: Helpers for task management, time tracking, and development
- **Theming**: Consistent color schemes across terminal and editors
- **Window Management**: Efficient i3wm setup with gaps and compositing

## Customization

To customize these configurations:

1. Fork this repository
2. Modify the config files
3. Create a new branch for your changes
4. Commit and push your changes

## License

MIT License - Feel free to use and modify these configurations
