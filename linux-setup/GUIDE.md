# Dual-boot EndeavourOS + Windows

Cheat sheet for setting up EndeavourOS alongside Windows using your config bundle.


## 1. Prep Windows (on her computer)

1. Back up important files to external drive or cloud
2. Open `diskmgmt.msc`, right-click the main Windows partition (usually C:), Shrink Volume
   - Free up at least 60GB, 100GB+ is better
3. Disable Fast Startup:
   - Control Panel > Power Options > "Choose what the power buttons do"
   - Click "Change settings that are currently unavailable"
   - Uncheck "Turn on fast startup", save
4. Reboot into BIOS (spam F2/Del/F12 during boot):
   - Disable Secure Boot
   - Confirm it's UEFI (almost certainly is on anything modern)


## 2. Install EndeavourOS

1. Plug in the flash drive, boot from it (F12 boot menu or change boot order in BIOS)
2. Select "Boot EndeavourOS"
3. Run the Calamares installer
4. At the partitioning step, pick Manual Partitioning:

| What | Where | Format | Size |
|------|-------|--------|------|
| EFI partition | The existing FAT32 ~100-500MB one | DO NOT FORMAT, just mount as `/boot/efi` | keep |
| Root `/` | New partition in free space | ext4 | 50-80GB |
| Swap | New partition | linux-swap | 8GB (or skip if 16GB+ RAM) |
| Home `/home` | New partition | ext4 | rest of free space |

Do not touch NTFS partitions. Leave them alone.

5. Finish installer. GRUB picks up Windows automatically.
6. Reboot, remove USB. You should see GRUB with both EndeavourOS and Windows.


## 3. First boot setup

Open a terminal and run these in order:

```bash
# System update
sudo pacman -Syu

# Install yay (AUR helper)
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay && makepkg -si
cd ~

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install zsh plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```


## 4. Install packages

Copy the `linux-setup/` folder to her machine (USB, rsync, whatever).

```bash
# Repo packages
sudo pacman -S --needed - < linux-setup/pkglist-native.txt

# AUR packages
yay -S --needed - < linux-setup/pkglist-aur.txt
```

Some packages might fail if they're specific to your hardware. That's fine, skip them.


## 5. Deploy dotfiles

```bash
# Configs
cp -r linux-setup/dotfiles/.config/* ~/.config/
cp linux-setup/dotfiles/.zshrc ~/
cp linux-setup/dotfiles/.gitconfig ~/

# Font
mkdir -p ~/.local/share/fonts
cp linux-setup/dotfiles/.local/share/fonts/* ~/.local/share/fonts/
fc-cache -fv

# Wallpaper (hyprpaper.conf points to this)
git clone https://github.com/ThePrimeagen/anime.git ~/Pictures/anime
```


## 6. Post-install tweaks

```bash
# Edit gitconfig with her name and email
nvim ~/.gitconfig

# Check monitor config after logging into Hyprland:
hyprctl monitors
# Edit ~/.config/hypr/monitors.conf if needed

# Set zsh as default shell
chsh -s /usr/bin/zsh

# Log out and back in (or reboot) to start Hyprland
```


## 7. Check everything

- [ ] GRUB shows both Windows and EndeavourOS
- [ ] Hyprland starts, wallpaper loads
- [ ] Waybar visible
- [ ] Ghostty opens (check keybind in hyprland.conf)
- [ ] Rofi launcher works
- [ ] Notifications (swaync) work
- [ ] Neovim opens, plugins install on first launch (`:Lazy sync`)
- [ ] Yazi opens
- [ ] Audio works (pavucontrol)
- [ ] Windows still boots fine from GRUB


## Troubleshooting

- GRUB doesn't show Windows: `sudo grub-mkconfig -o /boot/grub/grub.cfg`
- No display / black screen: probably GPU drivers. Boot into TTY (Ctrl+Alt+F2):
  - NVIDIA: `sudo pacman -S nvidia nvidia-utils`
  - AMD: should work out of the box (mesa)
- Package install errors: skip the failing ones, install manually later
- Hyprland won't start: check `~/.config/hypr/hyprland.conf` for errors, run `Hyprland` from TTY to see logs
