#!/usr/bin/env bash
# Waybar custom/network module — picks a wifi strength icon + class based on signal.

ICON_4="󰤨"
ICON_3="󰤥"
ICON_2="󰤢"
ICON_1="󰤟"
ICON_OFF="󰤮"
ICON_ETH="󰈀"

line=$(nmcli -t -f IN-USE,SSID,SIGNAL dev wifi 2>/dev/null | awk -F: '/^\*/ {print; exit}')

if [ -z "$line" ]; then
  eth=$(nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null \
    | awk -F: '$2=="ethernet" && $3=="connected" {print $1; exit}')
  if [ -n "$eth" ]; then
    ip=$(nmcli -t -f IP4.ADDRESS dev show "$eth" 2>/dev/null \
      | awk -F: 'NR==1 {sub("/.*","",$2); print $2}')
    printf '{"text":"%s %s","class":"ethernet","tooltip":"%s"}\n' "$ICON_ETH" "$ip" "$eth"
    exit 0
  fi
  printf '{"text":"%s Disconnected","class":"disconnected","tooltip":"No connection"}\n' "$ICON_OFF"
  exit 0
fi

ssid=$(printf '%s' "$line" | awk -F: '{print $2}')
signal=$(printf '%s' "$line" | awk -F: '{print $3}')

if [ "$signal" -ge 75 ]; then
  cls="good"; icon="$ICON_4"
elif [ "$signal" -ge 55 ]; then
  cls="good"; icon="$ICON_3"
elif [ "$signal" -ge 35 ]; then
  cls="mid";  icon="$ICON_2"
else
  cls="bad";  icon="$ICON_1"
fi

printf '{"text":"%s %s","class":"%s","tooltip":"%s — %s%%"}\n' "$icon" "$ssid" "$cls" "$ssid" "$signal"
