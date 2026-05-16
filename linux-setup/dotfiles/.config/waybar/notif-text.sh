#!/bin/bash

exec 2>/dev/null

NOTIF_FILE="/tmp/waybar-last-notif"
: > "$NOTIF_FILE"

MAX_CHARS="${WAYBAR_NOTIF_MAX_CHARS:-58}"

# Dbus Notify string order (strings only, skipping uint32/int32):
# 1: app_name, 2: icon (usually empty), 3: summary, 4: body
# Then an array follows.

dbus-monitor --session "interface='org.freedesktop.Notifications',member='Notify'" 2>/dev/null | \
while IFS= read -r line; do
    if [[ "$line" == *"member=Notify"* ]]; then
        str_count=0
        reading=true
        app_name=""
        summary=""
        body=""
        continue
    fi
    if [[ "$reading" == true ]]; then
        if [[ "$line" == *'string "'* ]]; then
            str_count=$((str_count + 1))
            val=$(echo "$line" | sed 's/.*string "//;s/"$//')
            case "$str_count" in
                1) app_name="$val" ;;
                3) summary="$val" ;;
                4) body="$val" ;;
            esac
        fi
        # Emit when we hit the array (all strings captured)
        if [[ "$line" == *"array ["* ]] && [ "$str_count" -ge 3 ]; then
            reading=false
            C="#8caaee"
            # Truncate app name and summary if too long
            if [ "${#app_name}" -gt 20 ]; then
                app_name="${app_name:0:17}..."
            fi
            if [ "${#summary}" -gt 20 ]; then
                summary="${summary:0:17}..."
            fi
            if [ -n "$app_name" ] && [ -n "$summary" ] && [ -n "$body" ]; then
                prefix="<span color='$C' font_style='italic'>[$app_name -> $summary]</span> "
                msg="$body"
            elif [ -n "$app_name" ] && [ -n "$summary" ]; then
                prefix="<span color='$C' font_style='italic'>[$app_name]</span> "
                msg="$summary"
            elif [ -n "$summary" ] && [ -n "$body" ]; then
                prefix="<span color='$C' font_style='italic'>[$summary]</span> "
                msg="$body"
            elif [ -n "$summary" ]; then
                prefix=""
                msg="$summary"
            else
                prefix=""
                msg="$body"
            fi
            # Limit total visible text (prefix without tags + msg)
            prefix_text=""
            if [ -n "$prefix" ]; then
                prefix_text=$(echo "$prefix" | sed 's/<[^>]*>//g')
            fi
            total_len=$(( ${#prefix_text} + ${#msg} ))
            if [ "$total_len" -gt "$MAX_CHARS" ]; then
                remaining=$(( MAX_CHARS - ${#prefix_text} ))
                if [ "$remaining" -gt 3 ]; then
                    msg="${msg:0:$(( remaining - 3 ))}..."
                else
                    msg="..."
                fi
            fi
            full="$prefix$msg"
            if [ -n "$full" ]; then
                echo "$full" > "$NOTIF_FILE"
                ( sleep 7 && : > "$NOTIF_FILE" ) &
            fi
        fi
    fi
done &

DBUS_PID=$!
trap "kill $DBUS_PID 2>/dev/null; rm -f $NOTIF_FILE" EXIT

prev=""
while true; do
    cur=$(cat "$NOTIF_FILE" 2>/dev/null)
    if [ "$cur" != "$prev" ]; then
        if [ -n "$cur" ]; then
            escaped=$(echo "$cur" | sed 's/\\/\\\\/g; s/"/\\"/g')
            printf '{"text": "%s", "class": "active"}\n' "$escaped"
        else
            printf '{"text": "", "class": "empty"}\n'
        fi
        prev="$cur"
    fi
    sleep 0.5
done
