#!/bin/sh
FLAG="$HOME/.cache/island/overlay-locked"
running() { pgrep -f "python3? .*waybar/overlay[.]py" >/dev/null; }
start() { running || setsid -f python3 "$HOME/.config/waybar/overlay.py" >/dev/null 2>&1; }
stop() { pkill -f "python3? .*waybar/overlay[.]py" 2>/dev/null; }
case "$1" in
show) start ;;
hide) [ -e "$FLAG" ] || stop ;;
toggle)
    if [ -e "$FLAG" ]; then rm -f "$FLAG"; stop
    else touch "$FLAG"; start; fi ;;
esac
