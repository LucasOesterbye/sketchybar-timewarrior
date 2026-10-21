#!/usr/bin/env bash
# sketchybar-timewarrior: settings, state files and the function that asks Timewarrior.
TW_DIR="$CONFIG_DIR/plugins/timewarrior"
source "$TW_DIR/config.sh"

# Fallbacks in case config.sh leaves something out
: "${TW_TAGS:=Work}" "${TW_POSITION:=right}" "${TW_WARN_HOURS:=0}" "${TW_AUTO_PAUSE:=1}"
: "${TW_RESUME_PROMPT:=1}" "${TW_FONT:=Hack Nerd Font}"
: "${TW_ACTIVE:=0xffa6e3a1}" "${TW_PAUSED:=0xfff9e2af}" "${TW_WARN:=0xfffab387}" "${TW_DIM:=0xff6c7086}"
: "${TW_TEXT:=0xffcdd6f4}" "${TW_STOP:=0xfff38ba8}" "${TW_ACCENT:=0xff89b4fa}" "${TW_HOVER:=0xff313244}"
: "${TW_POPUP_BG:=0xff1e1e2e}" "${TW_POPUP_BORDER:=0xff45475a}"

TIMEW="$(command -v timew || echo /opt/homebrew/bin/timew)"
export TIMEW TW_TAGS                  # stats.py reads both
TW_PY=/usr/bin/python3
TW_STATS="$TW_DIR/stats.py"

# Small state files, in your private cache folder
TW_STATE="$HOME/Library/Caches/sketchybar-timewarrior"
[ -d "$TW_STATE" ] || mkdir -p -m 700 "$TW_STATE"
TW_SESSION="$TW_STATE/session"      # category + seconds banked before pauses
TW_PAUSED_FLAG="$TW_STATE/paused"   # exists while paused
TW_LIVE="$TW_STATE/live"            # when Timewarrior was last asked + start of the running interval
TW_LAST_TICK="$TW_STATE/last_tick"  # last second the bar saw the timer running (sleep detection)
TW_POPUP="$TW_STATE/popup_open"     # time the menu was opened
TW_RANGE="$TW_STATE/range"          # summary range: day | week | month
TW_CHART="$TW_STATE/chart"          # week chart: shown | hidden

# Fills TW_TAG_LIST with the trimmed, non-empty categories from TW_TAGS
tw_load_tags() {
  TW_TAG_LIST=()
  local raw t
  IFS=';' read -ra raw <<< "$TW_TAGS"
  for t in "${raw[@]}"; do
    t="$(printf '%s' "$t" | sed 's/^ *//;s/ *$//')"
    [ -n "$t" ] && TW_TAG_LIST+=("$t")
  done
}

tw_hms() { printf '%d:%02d:%02d' $(($1 / 3600)) $(($1 % 3600 / 60)) $(($1 % 60)); }

# Unix time -> local time format (BSD date on macOS, GNU date elsewhere)
tw_fmt_epoch() { date -r "$1" "+$2" 2>/dev/null || date -d "@$1" "+$2"; }

tw_session_read() {
  TW_S_TAG=""; TW_S_BANK=0
  [ -f "$TW_SESSION" ] && { IFS= read -r TW_S_TAG; read -r TW_S_BANK; } < "$TW_SESSION"
  : "${TW_S_BANK:=0}"
}
tw_session_write() { printf '%s\n%s\n' "$1" "$2" > "$TW_SESSION.tmp" && mv "$TW_SESSION.tmp" "$TW_SESSION"; }

# Only one script at a time may ask Timewarrior or change the state.
# A mkdir lock; one left behind by a crashed script is broken after 5 seconds.
tw_lock() {
  local tries=0
  until mkdir "$TW_STATE/lock" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -ge 50 ]; then rmdir "$TW_STATE/lock" 2>/dev/null; tries=0; fi
    sleep 0.1
  done
}
tw_unlock() { rmdir "$TW_STATE/lock" 2>/dev/null; }

# Asks Timewarrior what is going on and refreshes the cache. Call it while holding the lock
# (or use tw_check_now). Sets:
#   TW_STATUS  tracking | paused | idle
#   TW_TAG     category (tracking or paused)
#   TW_SECS    session seconds, including time before pauses
#   TW_BANK    the part of TW_SECS from before the last pause
#   TW_START   start of the running interval (tracking only)
tw_check() {
  local now line
  now=$(date +%s)
  line="$("$TW_PY" "$TW_STATS" active 2>/dev/null)"     # "<start epoch><TAB><category>" or nothing
  TW_START=""; TW_TAG=""
  [ -n "$line" ] && IFS=$'\t' read -r TW_START TW_TAG <<< "$line"
  tw_session_read
  if [ -n "$TW_START" ]; then
    if [ "$TW_S_TAG" != "$TW_TAG" ]; then            # started outside the menu: new session
      TW_S_BANK=0; tw_session_write "$TW_TAG" 0
    fi
    rm -f "$TW_PAUSED_FLAG"
    TW_STATUS=tracking; TW_BANK=$TW_S_BANK; TW_SECS=$((TW_S_BANK + now - TW_START))
  elif [ -f "$TW_PAUSED_FLAG" ]; then
    TW_STATUS=paused; TW_TAG=$TW_S_TAG; TW_BANK=$TW_S_BANK; TW_SECS=$TW_S_BANK
  else
    rm -f "$TW_SESSION"
    TW_STATUS=idle; TW_BANK=0; TW_SECS=0
  fi
  printf '%s\n%s\n' "$now" "$TW_START" > "$TW_LIVE.tmp" && mv "$TW_LIVE.tmp" "$TW_LIVE"
}

tw_check_now() { tw_lock; tw_check; tw_unlock; }

# Stop the running interval (optionally as of a local time). Timewarrior refuses to stop an
# interval in the same second it started; such an empty interval is simply discarded.
tw_stop() {
  "$TIMEW" stop ${1:+"$1"} >/dev/null 2>&1 || "$TIMEW" stop >/dev/null 2>&1 || "$TIMEW" cancel >/dev/null 2>&1
}

# Same result, but trusts the cache for 10 seconds (used by the once-a-second tick)
tw_state() {
  local now checked=0
  now=$(date +%s)
  [ -f "$TW_LIVE" ] && { read -r checked; read -r TW_START; } < "$TW_LIVE"
  if [ $((now - ${checked:-0})) -ge 10 ]; then
    tw_check_now
    return
  fi
  tw_session_read
  if [ -n "$TW_START" ]; then
    TW_STATUS=tracking; TW_TAG=$TW_S_TAG; TW_SECS=$((TW_S_BANK + now - TW_START))
  elif [ -f "$TW_PAUSED_FLAG" ]; then
    TW_STATUS=paused; TW_TAG=$TW_S_TAG; TW_SECS=$TW_S_BANK
  else
    TW_STATUS=idle; TW_TAG=""; TW_SECS=0
  fi
}
