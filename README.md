# arch-setup

My Arch Linux + Hyprland dotfiles.

## What's inside

- **Hyprland** window manager + hyprlock + hyprpaper
- **Waybar** with custom notification module
- **Ghostty** terminal
- **Theme switching** for Hyprland, Ghostty, Waybar, Rofi, GTK, KDE/Qt, and tmux
- **Neovim** (lazy.nvim)
- **Rofi** launcher
- **SwayNC** notifications
- **Yazi** file manager
- tmux keyboard-first config and shell helpers
- Bundled anime wallpapers
- Package lists (pacman + AUR)

## Install

```bash
# clone
git clone https://github.com/grechman/arch-setup.git
cd arch-setup/linux-setup

# install packages
sudo pacman -S --needed - < pkglist-native.txt
yay -S --needed - < pkglist-aur.txt

# copy dotfiles
cp -r dotfiles/.config/* ~/.config/
cp dotfiles/.zshrc ~/
cp dotfiles/.zprofile ~/
cp dotfiles/.tmux.conf ~/
cp dotfiles/.gitconfig ~/  # edit name/email first
cp -r dotfiles/.local/* ~/.local/
cp -r Pictures/anime ~/Pictures/
```

## Commands

```bash
waybar-set list          # list Waybar layouts
waybar-set focus         # switch Waybar layout
wallpaper-set <image>    # update hyprpaper wallpaper
theme list               # list themes
theme kanagawa-dragon    # apply theme
reload-tabs              # attach/create tmux main session
newtab <name>            # create a named tmux window
tmkill [session]         # kill one session, or all tmux with no args
```

## Wallpapers

Anime wallpapers are bundled under `linux-setup/Pictures/anime`.
Shoutout to [ThePrimeagen](https://github.com/ThePrimeagen) for the original wallpaper repo.
