# arch-setup

My Arch Linux + Hyprland dotfiles.

## What's inside

- **Hyprland** window manager + hyprlock + hyprpaper
- **Waybar** with custom notification module
- **Ghostty** terminal
- **Neovim** (lazy.nvim)
- **Rofi** launcher
- **SwayNC** notifications
- **Yazi** file manager
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
cp dotfiles/.gitconfig ~/  # edit name/email first
```

## Wallpapers

Shoutout to [ThePrimeagen](https://github.com/ThePrimeagen) for the wallpapers.
