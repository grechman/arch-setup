#!/bin/bash

exec 2>/dev/null

emit() {
    printf '{"text": "%s", "alt": "%s", "class": "%s", "tooltip": "%s"}\n' \
        "$1" "$2" "$3" "$4" || exit 0
}

prev_count=0
new_until=0

swaync-client -swb 2>/dev/null | while IFS= read -r line; do
    [[ "$line" =~ ^\{ ]] || continue

    count=$(echo "$line" | jq -r '.text // "0"')
    alt=$(echo "$line"   | jq -r '.alt // "none"')
    class=$(echo "$line" | jq -r '.class // "none"')
    tooltip=$(echo "$line" | jq -r '.tooltip // ""')

    text=""
    if [ "$count" != "0" ] && [[ "$alt" != *"none"* ]]; then
        text="$count"
    fi

    if [ "$count" -gt "$prev_count" ] 2>/dev/null; then
        emit "$text" "$alt" "$class new" "$tooltip"
    else
        emit "$text" "$alt" "$class" "$tooltip"
    fi

    prev_count="$count"
done
