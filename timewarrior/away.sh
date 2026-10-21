#!/usr/bin/env bash
# Auto-pause while you're away, then offer to resume.
#   away.sh away         screen locked: pause
#   away.sh back         screen unlocked: ask "Resume?"
#   away.sh gap <epoch>  the bar noticed the Mac slept while tracking: pause as of <epoch>, then ask
source "$CONFIG_DIR/plugins/timewarrior/lib.sh"
[ "$TW_AUTO_PAUSE" = 1 ] || exit 0

AUTO="$TW_STATE/auto_paused"   # local HH:MM of the auto-pause, until we've asked
LOCKED="$TW_STATE/locked"

# Pause the running interval as of unix time $1, banking the session time.
# Never later than the bar's last tick: that's the last moment we know you were here,
# even if this handler only gets to run after the Mac wakes up.
pause_at() {
  local at=$1 last=""
  [ -f "$TW_LAST_TICK" ] && read -r last < "$TW_LAST_TICK"
  [ -n "$last" ] && [ "$last" -lt "$at" ] && at=$last
  tw_lock
  tw_check
  if [ "$TW_STATUS" = "tracking" ]; then
    [ "$at" -gt "$TW_START" ] || at=$(date +%s)
    tw_stop "$(tw_fmt_epoch "$at" %Y-%m-%dT%H:%M:%S)"
    tw_session_write "$TW_TAG" $((TW_BANK + at - TW_START))
    touch "$TW_PAUSED_FLAG"
    rm -f "$TW_LAST_TICK" "$TW_LIVE"
    tw_fmt_epoch "$at" %H:%M > "$AUTO"
  fi
  tw_unlock
}

# Ask once: the atomic mv stops two events from both asking
offer_resume() {
  mv "$AUTO" "$AUTO.taken" 2>/dev/null || return 0
  local since tag answer
  since="$(cat "$AUTO.taken")"; rm -f "$AUTO.taken"
  [ -f "$TW_PAUSED_FLAG" ] || return 0             # already resumed or stopped
  tw_session_read
  tag="$(printf '%s' "$TW_S_TAG" | tr -d '"\\')"
  if [ "$TW_RESUME_PROMPT" = 1 ]; then
    answer="$(osascript -e "display dialog \"You were away, so $tag was paused at $since.\" with title \"Timewarrior\" buttons {\"Stay paused\", \"Resume $tag\"} default button 2 giving up after 120" 2>/dev/null)"
    case "$answer" in
      *"button returned:Resume"*) [ -f "$TW_PAUSED_FLAG" ] && "$TW_DIR/action.sh" pause ;;
    esac
  else
    osascript -e "display notification \"$tag was paused at $since while you were away.\" with title \"Timewarrior\"" >/dev/null 2>&1
  fi
}

refresh_bar() { NAME=timew SENDER=refresh "$TW_DIR/timew.sh"; }

case "$1" in
  away)
    touch "$LOCKED"
    pause_at "$(date +%s)"
    refresh_bar ;;
  back)
    rm -f "$LOCKED"
    refresh_bar
    offer_resume ;;
  gap)
    pause_at "$2"
    refresh_bar
    [ -f "$LOCKED" ] || offer_resume ;;          # on the lock screen: the unlock will ask
esac
