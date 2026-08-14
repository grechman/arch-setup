#!/usr/bin/env bash
set -uo pipefail

ICON_4="󰤨"
ICON_3="󰤥"
ICON_2="󰤢"
ICON_1="󰤟"
ICON_0="󰤯"
LOCK=""
OPEN=""

BG="#181616"
BG_ALT="#282727"
FG="#c5c9c5"
FG_ALT="#a6a69c"
FG_MUTED="#625e5a"
ACCENT="#658594"

DEVICE=""
ACTIVE_UUID=""
PROGRESS_PID=""
RESCAN_FLAG="${XDG_RUNTIME_DIR:-/tmp}/waybar-wifi-force-rescan"
SCAN_STAMP="${XDG_RUNTIME_DIR:-/tmp}/waybar-wifi-last-scan"
SCAN_MAX_AGE=20
NO_REFRESH=0
SHOW_SCAN_STATUS=1

declare -a FIELDS
declare -a SSIDS
declare -a SECURITIES
declare -a SIGNALS
declare -a CURRENTS
declare -a SAVED_UUIDS
declare -a ROWS
declare -A PROFILE_UUID
declare -A PROFILE_NAME_SET
declare -A NETWORK_INDEX

split_nmcli_line() {
  local line="$1"
  local field=""
  local char
  local escaped=0
  local i
  FIELDS=()

  for ((i = 0; i < ${#line}; i++)); do
    char="${line:i:1}"
    if ((escaped)); then
      field+="$char"
      escaped=0
    elif [[ "$char" == "\\" ]]; then
      escaped=1
    elif [[ "$char" == ":" ]]; then
      FIELDS+=("$field")
      field=""
    else
      field+="$char"
    fi
  done

  ((escaped)) && field+="\\"
  FIELDS+=("$field")
}

clean_text() {
  local text="${1//$'\t'/ }"
  text="${text//$'\r'/ }"
  text="${text//$'\n'/ }"
  printf '%s' "$text"
}

short_text() {
  local text
  local limit="${2:-64}"
  text="$(clean_text "$1")"
  if ((${#text} <= limit)); then
    printf '%s' "$text"
  else
    printf '%s...' "${text:0:limit - 3}"
  fi
}

load_colors() {
  local file="$HOME/.config/waybar/colors.css"
  local at name value rest
  [[ -r "$file" ]] || return 0

  while read -r at name value rest; do
    [[ "$at" == "@define-color" ]] || continue
    value="${value%;}"
    case "$name" in
      bg) BG="$value" ;;
      bg_alt) BG_ALT="$value" ;;
      fg) FG="$value" ;;
      fg_alt) FG_ALT="$value" ;;
      fg_muted) FG_MUTED="$value" ;;
      accent) ACCENT="$value" ;;
    esac
  done < "$file"
}

menu_theme() {
  cat <<EOF
* {
  font: "JetBrainsMono Nerd Font 12";
  background-color: transparent;
  text-color: $FG_ALT;
}
window {
  width: 455px;
  location: north east;
  anchor: north east;
  x-offset: -10px;
  y-offset: 4px;
  padding: 8px;
  background-color: $BG;
  border: 1px;
  border-color: $FG_MUTED;
  border-radius: 6px;
}
mainbox {
  background-color: transparent;
  children: [listview];
}
listview {
  lines: 8;
  scrollbar: false;
  spacing: 1px;
  fixed-height: false;
  background-color: transparent;
}
element {
  padding: 4px 6px;
  border-radius: 4px;
  background-color: transparent;
}
element normal.normal,
element alternate.normal,
element normal.active,
element alternate.active,
element normal.urgent,
element alternate.urgent {
  background-color: transparent;
  text-color: $FG_ALT;
}
element selected.normal,
element selected.active,
element selected.urgent {
  background-color: $ACCENT;
  text-color: $BG;
}
element-text {
  text-color: inherit;
}
EOF
}

password_theme() {
  cat <<EOF
* {
  font: "JetBrainsMono Nerd Font 12";
  background-color: transparent;
  text-color: $FG_ALT;
}
window {
  width: 420px;
  location: north east;
  anchor: north east;
  x-offset: -10px;
  y-offset: 4px;
  padding: 8px;
  background-color: $BG;
  border: 1px;
  border-color: $FG_MUTED;
  border-radius: 6px;
}
mainbox {
  spacing: 6px;
  children: [message, inputbar];
}
message {
  padding: 0 2px 2px 2px;
  text-color: $FG_ALT;
}
textbox {
  text-color: $FG_ALT;
}
inputbar {
  padding: 5px 6px;
  background-color: $BG_ALT;
  children: [prompt, entry];
}
prompt {
  text-color: $ACCENT;
  padding: 0 8px 0 0;
}
entry {
  text-color: $FG;
  placeholder: "";
  placeholder-color: transparent;
}
EOF
}

error_theme() {
  cat <<EOF
* {
  font: "JetBrainsMono Nerd Font 12";
  background-color: transparent;
  text-color: $FG_ALT;
}
window {
  width: 420px;
  location: north east;
  anchor: north east;
  x-offset: -10px;
  y-offset: 4px;
  padding: 10px;
  background-color: $BG;
  border: 1px;
  border-color: $FG_MUTED;
  border-radius: 6px;
}
textbox {
  text-color: $FG_ALT;
}
EOF
}

progress_theme() {
  cat <<EOF
* {
  font: "JetBrainsMono Nerd Font 12";
  background-color: transparent;
  text-color: $FG_ALT;
}
window {
  width: 360px;
  location: north east;
  anchor: north east;
  x-offset: -10px;
  y-offset: 4px;
  padding: 10px;
  background-color: $BG;
  border: 1px;
  border-color: $FG_MUTED;
  border-radius: 6px;
}
textbox {
  text-color: $FG_ALT;
}
EOF
}

stop_progress() {
  [[ -n "$PROGRESS_PID" ]] || return 0
  kill "$PROGRESS_PID" >/dev/null 2>&1 || true
  wait "$PROGRESS_PID" >/dev/null 2>&1 || true
  PROGRESS_PID=""
}

start_progress() {
  stop_progress
  rofi \
    -no-config \
    -e "󰤨 connecting $(short_text "$1" 48)" \
    -theme-str "$(progress_theme)" \
    >/dev/null 2>&1 &
  PROGRESS_PID=$!
  sleep 0.05
}

start_status() {
  stop_progress
  rofi \
    -no-config \
    -e "$1" \
    -theme-str "$(progress_theme)" \
    >/dev/null 2>&1 &
  PROGRESS_PID=$!
  sleep 0.05
}

notify() {
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send -a waybar "$1" "$2" >/dev/null 2>&1 || true
}

show_error() {
  local message
  message="$(short_text "$1" 180)"
  rofi -no-config -e "$message" -theme-str "$(error_theme)" >/dev/null 2>&1 || true
}

die() {
  stop_progress
  show_error "$1"
  exit 1
}

trap stop_progress EXIT

require_tools() {
  command -v nmcli >/dev/null 2>&1 || die "missing: nmcli"
  command -v rofi >/dev/null 2>&1 || die "missing: rofi"
}

first_error_line() {
  local text="$1"
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && {
      short_text "$line" 180
      return 0
    }
  done <<< "$text"
  printf 'command failed'
}

wifi_device() {
  local line device kind state fallback=""
  while IFS= read -r line; do
    split_nmcli_line "$line"
    ((${#FIELDS[@]} >= 3)) || continue
    device="${FIELDS[0]}"
    kind="${FIELDS[1]}"
    state="${FIELDS[2]}"
    [[ "$kind" == "wifi" ]] || continue
    [[ -z "$fallback" ]] && fallback="$device"
    if [[ "$state" == connected* ]]; then
      printf '%s' "$device"
      return 0
    fi
  done < <(nmcli -t -e yes -f DEVICE,TYPE,STATE device 2>/dev/null)

  [[ -n "$fallback" ]] || return 1
  printf '%s' "$fallback"
}

load_profiles() {
  local line name uuid kind device
  ACTIVE_UUID=""
  PROFILE_UUID=()
  PROFILE_NAME_SET=()

  while IFS= read -r line; do
    split_nmcli_line "$line"
    ((${#FIELDS[@]} >= 4)) || continue
    name="${FIELDS[0]}"
    uuid="${FIELDS[1]}"
    kind="${FIELDS[2]}"
    device="${FIELDS[3]}"
    PROFILE_NAME_SET["$name"]=1
    [[ "$kind" == "802-11-wireless" ]] || continue
    [[ "$device" == "$DEVICE" ]] && ACTIVE_UUID="$uuid"
    [[ -n "${PROFILE_UUID[$name]+x}" && -z "$device" ]] && continue
    PROFILE_UUID["$name"]="$uuid"
  done < <(nmcli -t -e yes -f NAME,UUID,TYPE,DEVICE connection show 2>/dev/null)
}

signal_icon() {
  local signal="$1"
  if ((signal >= 75)); then
    printf '%s' "$ICON_4"
  elif ((signal >= 55)); then
    printf '%s' "$ICON_3"
  elif ((signal >= 35)); then
    printf '%s' "$ICON_2"
  elif ((signal > 0)); then
    printf '%s' "$ICON_1"
  else
    printf '%s' "$ICON_0"
  fi
}

is_open_security() {
  [[ -z "$1" || "$1" == "--" ]]
}

security_label() {
  local security="$1"
  if is_open_security "$security"; then
    printf 'open'
  else
    security="${security// /\/}"
    short_text "$security" 9
  fi
}

security_icon() {
  if is_open_security "$1"; then
    printf '%s' "$OPEN"
  else
    printf '%s' "$LOCK"
  fi
}

row_status() {
  local index="$1"
  if [[ "${CURRENTS[$index]}" == "1" ]]; then
    printf 'current'
  elif [[ -n "${SAVED_UUIDS[$index]}" ]]; then
    printf 'saved'
  else
    printf ''
  fi
}

add_or_update_network() {
  local ssid="$1"
  local security="$2"
  local signal="$3"
  local current="$4"
  local saved_uuid="${PROFILE_UUID[$ssid]-}"
  local index="${NETWORK_INDEX[$ssid]-}"

  if [[ -n "$index" ]]; then
    if [[ "$current" == "1" || ( "${CURRENTS[$index]}" != "1" && "$signal" -gt "${SIGNALS[$index]}" ) ]]; then
      SSIDS[$index]="$ssid"
      SECURITIES[$index]="$security"
      SIGNALS[$index]="$signal"
      CURRENTS[$index]="$current"
      SAVED_UUIDS[$index]="$saved_uuid"
    fi
    return 0
  fi

  index="${#SSIDS[@]}"
  NETWORK_INDEX["$ssid"]="$index"
  SSIDS[$index]="$ssid"
  SECURITIES[$index]="$security"
  SIGNALS[$index]="$signal"
  CURRENTS[$index]="$current"
  SAVED_UUIDS[$index]="$saved_uuid"
}

load_networks() {
  local rescan="${1:-no}"
  local line in_use ssid security signal
  SSIDS=()
  SECURITIES=()
  SIGNALS=()
  CURRENTS=()
  SAVED_UUIDS=()
  NETWORK_INDEX=()

  while IFS= read -r line; do
    split_nmcli_line "$line"
    ((${#FIELDS[@]} >= 4)) || continue
    in_use="${FIELDS[0]}"
    ssid="${FIELDS[1]}"
    security="${FIELDS[2]}"
    signal="${FIELDS[3]}"
    ssid="$(clean_text "$ssid")"
    [[ -n "$ssid" ]] || continue
    [[ "$signal" =~ ^[0-9]+$ ]] || signal=0
    ((signal > 100)) && signal=100
    add_or_update_network "$ssid" "${security:-"--"}" "$signal" "$([[ "$in_use" == "*" ]] && printf 1 || printf 0)"
  done < <(nmcli -t -e yes -f IN-USE,SSID,SECURITY,SIGNAL device wifi list --rescan "$rescan" ifname "$DEVICE" 2>/dev/null)

  if [[ "$rescan" == "yes" ]]; then
    date +%s > "$SCAN_STAMP" 2>/dev/null || true
  fi
}

sort_networks() {
  local -a old_ssids=("${SSIDS[@]}")
  local -a old_securities=("${SECURITIES[@]}")
  local -a old_signals=("${SIGNALS[@]}")
  local -a old_currents=("${CURRENTS[@]}")
  local -a old_saved_uuids=("${SAVED_UUIDS[@]}")
  local -a order=()
  local i index current_rank

  while IFS= read -r index; do
    [[ -n "$index" ]] && order+=("$index")
  done < <(
    for ((i = 0; i < ${#old_ssids[@]}; i++)); do
      current_rank=1
      [[ "${old_currents[$i]}" == "1" ]] && current_rank=0
      printf '%d\t%03d\t%d\n' "$current_rank" "$((1000 - old_signals[$i]))" "$i"
    done | sort -n -k1,1 -k2,2 | cut -f3
  )

  SSIDS=()
  SECURITIES=()
  SIGNALS=()
  CURRENTS=()
  SAVED_UUIDS=()

  for index in "${order[@]}"; do
    SSIDS+=("${old_ssids[$index]}")
    SECURITIES+=("${old_securities[$index]}")
    SIGNALS+=("${old_signals[$index]}")
    CURRENTS+=("${old_currents[$index]}")
    SAVED_UUIDS+=("${old_saved_uuids[$index]}")
  done
}

build_rows() {
  local i marker icon lock sec ssid
  ROWS=()
  for ((i = 0; i < ${#SSIDS[@]}; i++)); do
    marker=" "
    [[ "${CURRENTS[$i]}" == "1" ]] && marker="●"
    icon="$(signal_icon "${SIGNALS[$i]}")"
    lock="$(security_icon "${SECURITIES[$i]}")"
    sec="$(security_label "${SECURITIES[$i]}")"
    ssid="$(short_text "${SSIDS[$i]}" 34)"
    ROWS+=("$(printf '%s %s %3d%% %s %-9s %s' "$marker" "$icon" "${SIGNALS[$i]}" "$lock" "$sec" "$ssid")")
  done
}

choose_network() {
  choose_network_static
}

choose_network_static() {
  local output
  local lines="${#ROWS[@]}"
  ((lines > 8)) && lines=8

  output="$(
    printf '%s\n' "${ROWS[@]}" | rofi \
      -no-config \
      -dmenu \
      -no-custom \
      -selected-row 0 \
      -l "$lines" \
      -format i \
      -theme-str "$(menu_theme)"
  )"
  local code=$?
  [[ "$code" -eq 0 && "$output" =~ ^[0-9]+$ ]] || return 1
  [[ "$output" -ge 0 && "$output" -lt "${#SSIDS[@]}" ]] || return 1
  printf '%s' "$output"
}

ask_password() {
  local ssid="$1"
  local output
  output="$(
    rofi \
      -no-config \
      -dmenu \
      -password \
      -p key \
      -l 0 \
      -mesg "$(short_text "$ssid" 64)" \
      -theme-str "$(password_theme)" \
      < /dev/null
  )"
  local code=$?
  [[ "$code" -eq 0 && -n "$output" ]] || return 1
  printf '%s' "$output"
}

secret_property() {
  local security="${1^^}"
  if [[ "$security" == *WEP* ]]; then
    printf '802-11-wireless-security.wep-key0'
  else
    printf '802-11-wireless-security.psk'
  fi
}

unsupported_security() {
  local security="${1^^}"
  [[ "$security" == *802.1X* || "$security" == *EAP* ]]
}

run_nmcli() {
  local output
  output="$("$@" 2>&1 >/dev/null)"
  local code=$?
  if ((code != 0)); then
    printf '%s' "$output"
    return "$code"
  fi
  return 0
}

run_with_passwd_file() {
  local property="$1"
  local password="$2"
  shift 2
  local file output code
  file="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/waybar-wifi.XXXXXX")" || return 1
  chmod 600 "$file" 2>/dev/null || true
  printf '%s:%s\n' "$property" "$password" > "$file"
  output="$("$@" passwd-file "$file" 2>&1 >/dev/null)"
  code=$?
  rm -f "$file"
  if ((code != 0)); then
    printf '%s' "$output"
    return "$code"
  fi
  return 0
}

connect_saved() {
  local index="$1"
  local output password code
  start_progress "${SSIDS[$index]}"
  output="$(run_nmcli nmcli --wait 45 connection up uuid "${SAVED_UUIDS[$index]}" ifname "$DEVICE")"
  code=$?
  if ((code == 0)); then
    stop_progress
    return 0
  fi
  stop_progress

  if [[ "${output,,}" != *secret* && "${output,,}" != *password* ]]; then
    die "$(first_error_line "$output")"
  fi

  password="$(ask_password "${SSIDS[$index]}")" || return 1
  start_progress "${SSIDS[$index]}"
  output="$(run_with_passwd_file "$(secret_property "${SECURITIES[$index]}")" "$password" nmcli --wait 45 connection up uuid "${SAVED_UUIDS[$index]}" ifname "$DEVICE")"
  code=$?
  stop_progress
  ((code == 0)) || die "$(first_error_line "$output")"
}

connect_open() {
  local index="$1"
  local output code
  start_progress "${SSIDS[$index]}"
  output="$(run_nmcli nmcli --wait 45 device wifi connect "${SSIDS[$index]}" ifname "$DEVICE")"
  code=$?
  stop_progress
  ((code == 0)) || die "$(first_error_line "$output")"
}

disconnect_current() {
  local index="$1"
  local output code uuid
  uuid="${ACTIVE_UUID:-${SAVED_UUIDS[$index]}}"
  [[ -n "$uuid" ]] || die "active Wi-Fi connection not found"

  start_status "󰤭 disconnecting $(short_text "${SSIDS[$index]}" 48)"
  output="$(run_nmcli nmcli --wait 15 connection down uuid "$uuid")"
  code=$?
  stop_progress
  ((code == 0)) || die "$(first_error_line "$output")"
  : > "$RESCAN_FLAG" 2>/dev/null || true
  notify "Wi-Fi" "Disconnected from $(short_text "${SSIDS[$index]}" 64)"
}

scan_cache_is_fresh() {
  local stamp now
  [[ -r "$SCAN_STAMP" ]] || return 1
  read -r stamp < "$SCAN_STAMP" || return 1
  [[ "$stamp" =~ ^[0-9]+$ ]] || return 1
  now="$(date +%s)"
  ((now - stamp <= SCAN_MAX_AGE))
}

refresh_networks() {
  if ((SHOW_SCAN_STATUS)); then
    start_status "󰤨 scanning networks"
  fi
  load_networks yes
  if ((SHOW_SCAN_STATUS)); then
    stop_progress
  fi
}

unique_connection_name() {
  local base candidate suffix
  base="$(short_text "${1:-Wi-Fi}" 48)"
  [[ -n "$base" ]] || base="Wi-Fi"
  candidate="$base"
  suffix=2
  while [[ -n "${PROFILE_NAME_SET[$candidate]+x}" ]]; do
    candidate="$base $suffix"
    ((suffix++))
  done
  printf '%s' "$candidate"
}

configure_security() {
  local connection_name="$1"
  local security="${2^^}"
  local output key_mgmt code

  if [[ "$security" == *WEP* ]]; then
    output="$(run_nmcli nmcli connection modify "$connection_name" wifi-sec.key-mgmt none wifi-sec.wep-key-type key wifi-sec.wep-key-flags 0)"
    code=$?
    ((code == 0)) || die "$(first_error_line "$output")"
    return 0
  fi

  key_mgmt="wpa-psk"
  [[ "$security" == *WPA3* && "$security" != *WPA2* ]] && key_mgmt="sae"
  output="$(run_nmcli nmcli connection modify "$connection_name" wifi-sec.key-mgmt "$key_mgmt" wifi-sec.psk-flags 0)"
  code=$?
  ((code == 0)) || die "$(first_error_line "$output")"
}

connect_secured() {
  local index="$1"
  local password connection_name output code created=0

  unsupported_security "${SECURITIES[$index]}" && die "enterprise Wi-Fi needs more than a password"
  password="$(ask_password "${SSIDS[$index]}")" || return 1
  connection_name="$(unique_connection_name "${SSIDS[$index]}")"

  start_progress "${SSIDS[$index]}"
  output="$(run_nmcli nmcli connection add type wifi ifname "$DEVICE" con-name "$connection_name" ssid "${SSIDS[$index]}")"
  code=$?
  ((code == 0)) || die "$(first_error_line "$output")"
  created=1

  configure_security "$connection_name" "${SECURITIES[$index]}"

  output="$(run_with_passwd_file "$(secret_property "${SECURITIES[$index]}")" "$password" nmcli --wait 45 connection up "$connection_name" ifname "$DEVICE")"
  code=$?
  stop_progress
  if ((code != 0)); then
    ((created)) && nmcli connection delete "$connection_name" >/dev/null 2>&1 || true
    die "$(first_error_line "$output")"
  fi
}

connect_index() {
  local index="$1"

  if [[ "${CURRENTS[$index]}" == "1" ]]; then
    disconnect_current "$index"
    return 0
  fi

  if [[ -n "${SAVED_UUIDS[$index]}" ]]; then
    connect_saved "$index" || return 0
  elif is_open_security "${SECURITIES[$index]}"; then
    connect_open "$index"
  else
    connect_secured "$index" || return 0
  fi

  notify "Wi-Fi" "Connected to $(short_text "${SSIDS[$index]}" 64)"
}

load_context() {
  local force_scan=0 had_rescan_flag=0
  require_tools
  DEVICE="$(wifi_device)" || die "no Wi-Fi device found"
  load_profiles

  if [[ -f "$RESCAN_FLAG" ]]; then
    had_rescan_flag=1
    force_scan=1
  fi

  if ((NO_REFRESH)); then
    load_networks no
  elif ((force_scan)) || ! scan_cache_is_fresh; then
    refresh_networks
  else
    load_networks no
  fi

  if ((had_rescan_flag)); then
    rm -f "$RESCAN_FLAG"
  fi

  if ((${#SSIDS[@]} == 0)) && ((!NO_REFRESH)); then
    refresh_networks
  fi

  ((${#SSIDS[@]} > 0)) || die "no Wi-Fi networks found"
  sort_networks
  build_rows
}

theme_check() {
  rofi -no-config -dump-theme -theme-str "$(menu_theme)" >/dev/null || return 1
  rofi -no-config -dump-theme -theme-str "$(password_theme)" >/dev/null || return 1
  rofi -no-config -dump-theme -theme-str "$(error_theme)" >/dev/null || return 1
  rofi -no-config -dump-theme -theme-str "$(progress_theme)" >/dev/null || return 1
}

dry_action() {
  local index="$1"
  if [[ "${CURRENTS[$index]}" == "1" ]]; then
    printf 'disconnect'
  elif [[ -n "${SAVED_UUIDS[$index]}" ]]; then
    printf 'connect-saved'
  elif is_open_security "${SECURITIES[$index]}"; then
    printf 'connect-open'
  else
    printf 'ask-key'
  fi
}

main() {
  local check=0
  local check_theme=0
  local dry_index=""
  local print_rows=0
  local progress_check=0
  local selected

  while (($#)); do
    case "$1" in
      --check)
        check=1
        ;;
      --theme-check)
        check_theme=1
        ;;
      --print-rows)
        print_rows=1
        ;;
      --progress-check)
        progress_check=1
        ;;
      --no-refresh)
        NO_REFRESH=1
        ;;
      --dry-run-index)
        shift
        [[ $# -gt 0 ]] || die "missing dry-run index"
        dry_index="$1"
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
    shift
  done

  load_colors

  if ((check || print_rows)) || [[ -n "$dry_index" ]]; then
    SHOW_SCAN_STATUS=0
  fi

  if ((check_theme)); then
    theme_check || die "rofi theme validation failed"
    return 0
  fi

  if ((progress_check)); then
    start_progress "test"
    sleep 0.4
    stop_progress
    return 0
  fi

  load_context

  if ((check)); then
    local saved_visible=0
    local i
    for ((i = 0; i < ${#SSIDS[@]}; i++)); do
      [[ -n "${SAVED_UUIDS[$i]}" ]] && ((saved_visible++))
    done
    printf 'device=%s networks=%d saved-visible=%d profiles=%d\n' "$DEVICE" "${#SSIDS[@]}" "$saved_visible" "${#PROFILE_NAME_SET[@]}"
    return 0
  fi

  if ((print_rows)); then
    printf '%s\n' "${ROWS[@]}"
    return 0
  fi

  if [[ -n "$dry_index" ]]; then
    [[ "$dry_index" =~ ^[0-9]+$ && "$dry_index" -lt "${#SSIDS[@]}" ]] || die "dry-run index is out of range"
    printf 'action=%s current=%s saved=%s security=%s\n' \
      "$(dry_action "$dry_index")" \
      "$([[ "${CURRENTS[$dry_index]}" == "1" ]] && printf true || printf false)" \
      "$([[ -n "${SAVED_UUIDS[$dry_index]}" ]] && printf true || printf false)" \
      "$(security_label "${SECURITIES[$dry_index]}")"
    return 0
  fi

  selected="$(choose_network)" || return 0
  connect_index "$selected"
}

main "$@"
