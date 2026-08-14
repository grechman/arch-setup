# arch-setup bootstrap

This repo turns a fresh Arch-based install (Arch, EndeavourOS) into grechman's full working environment. When asked to "set up this machine" (or similar), execute the sequence below in order. Report failures at the end instead of stopping, unless a step's failure blocks the rest.

For the OS install itself (dual-boot partitioning etc.) see `linux-setup/GUIDE.md` - that part is manual.

## Sequence

1. **Sanity**: confirm this is an Arch-based distro with internet and sudo. Confirm `linux-setup/` is present.
2. **Packages**:
   - `sudo pacman -S --needed - < linux-setup/pkglist-native.txt`
   - If `yay` is missing, install it from AUR first (clone `https://aur.archlinux.org/yay.git`, makepkg -si).
   - `yay -S --needed - < linux-setup/pkglist-aur.txt`
   - Package conflicts or dead AUR packages: skip, note in the final report.
3. **Dotfiles**: before copying, back up anything that exists (`mv ~/.config/<x> ~/.config-backup-<date>/<x>`). Then copy per `README.md`: `dotfiles/.config/*` into `~/.config/`, home dotfiles (`.zshrc`, `.zprofile`, `.tmux.conf`, `.gitconfig`, `.gtkrc-2.0`) into `~/`, `dotfiles/.local/*` into `~/.local/`, `Pictures/anime` into `~/Pictures/`.
4. **System files** (`linux-setup/system/`):
   - kira-web (SearXNG + fetch web tools): `sudo cp -r system/kira-web /opt/`, generate a random `secret_key` in `/opt/kira-web/searxng/settings.yml` (placeholder marks the spot), `sudo cp system/kira-web/web_fetch system/kira-web/web_search /usr/local/bin/`, `sudo cp system/kira-web/systemd/kira-web.service /etc/systemd/system/`, then `sudo systemctl enable --now docker kira-web` (needs the docker package, it is in the pkglist).
   - tty1 autologin (boots straight into the Hyprland session): `sudo install -Dm644 system/getty-autologin/override.conf /etc/systemd/system/getty@tty1.service.d/override.conf` - edit the username inside first if it is not grechman.
5. **Private config**: clone the private Claude config - `git clone https://github.com/grechman/.claude ~/.claude` (private repo: the user must authenticate; ask them to run the clone or set up auth, don't guess credentials). Then read `~/.claude/private/MIGRATION.md` and finish the setup from there: secrets to re-enter, machine-to-machine copies, installs (oh-my-zsh, nvim plugins bootstrap, watermarks-remover symlink, etc.).
   - `~/.zshrc` sources `~/.zshrc.private` (guarded, absence is fine). Create it from `~/.claude/private/zshrc.private` and have the user fill the real values.
6. **Sanity checks**: Hyprland session starts, waybar renders (battery module included), `theme-apply kanagawa-dragon` works, `claude` starts and loads memory, `web_search "test"` returns results.

## Rules

- Never commit secrets to this repo; it is public. Machine-specific or secret shell lines belong in `~/.zshrc.private`.
- This repo is a snapshot, not a live mirror: after changing configs on a running machine, re-sync `dotfiles/` from `~/.config` and regenerate the pkglists (`pacman -Qqen`, `pacman -Qqem`, `pacman -Qqe`) before committing.
