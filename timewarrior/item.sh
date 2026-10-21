#!/usr/bin/env bash
# sketchybar-timewarrior: creates the bar item and its menu.
# Add to your sketchybarrc:   source "$CONFIG_DIR/plugins/timewarrior/item.sh"
# Settings: plugins/timewarrior/config.sh
source "$CONFIG_DIR/plugins/timewarrior/lib.sh"
TW_ACTION="CONFIG_DIR=$CONFIG_DIR $TW_DIR/action.sh"
rm -f "$TW_POPUP"

# timew_update: run `sketchybar --trigger timew_update` (e.g. from a shell alias) to refresh at once
sketchybar --add event timew_update \
           --add event timew_screen_locked com.apple.screenIsLocked \
           --add event timew_screen_unlocked com.apple.screenIsUnlocked

# Bar item. Left-click: menu. Right-click: pause / resume.
sketchybar --add item timew "$TW_POSITION" \
  --set timew icon= icon.color=$TW_DIM update_freq=30 updates=on \
        label.font="$TW_FONT Mono:Bold:13.0" \
        script="$TW_DIR/timew.sh" \
        popup.background.color=$TW_POPUP_BG popup.background.border_color=$TW_POPUP_BORDER \
        popup.background.border_width=2 popup.background.corner_radius=8 \
        popup.align=right \
  --subscribe timew mouse.clicked mouse.exited.global timew_update \
              timew_screen_locked timew_screen_unlocked

# Menu rows. background.drawing=off must come after background.color (a colour switches it on)
TW_ROW=(background.color=$TW_HOVER background.corner_radius=6 background.height=24
        background.padding_left=6 background.padding_right=6 background.drawing=off
        icon.font="$TW_FONT:Bold:13.0" icon.width=26 icon.padding_left=12 icon.padding_right=0
        label.font="$TW_FONT Mono:Regular:12.0" label.color=$TW_TEXT label.width=250
        label.padding_left=4 label.padding_right=12)
TW_HEADER=("${TW_ROW[@]}" label.font="$TW_FONT Mono:Bold:12.0")
TW_DATA=("${TW_ROW[@]}" icon.drawing=off label.padding_left=42 drawing=off)

# Clickable row: $1 = item, then its settings
tw_button() {
  local item=$1; shift
  sketchybar --add item "$item" popup.timew \
             --set "$item" "${TW_ROW[@]}" script="$TW_DIR/hover.sh" "$@" \
             --subscribe "$item" mouse.entered mouse.exited
}

sketchybar --add item timew.now popup.timew --set timew.now "${TW_HEADER[@]}"
tw_button timew.pause icon.color=$TW_PAUSED click_script="$TW_ACTION pause"
tw_button timew.stop  icon= icon.color=$TW_STOP label="Stop" click_script="$TW_ACTION stop"

sketchybar --add item timew.starthead popup.timew \
           --set timew.starthead "${TW_ROW[@]}" icon.drawing=off label.padding_left=12 \
                 label="Start / switch to:" label.color=$TW_DIM
tw_load_tags
for i in "${!TW_TAG_LIST[@]}"; do
  tw_button timew.tag.$((i + 1)) click_script="$TW_ACTION start $((i + 1))"
done

tw_button timew.sumhead "${TW_HEADER[@]}" icon= icon.color=$TW_ACCENT click_script="$TW_ACTION range"
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  sketchybar --add item timew.row.$i popup.timew --set timew.row.$i "${TW_DATA[@]}"
done

tw_button timew.charthead "${TW_HEADER[@]}" icon= icon.color=$TW_ACCENT click_script="$TW_ACTION chart"
for d in 1 2 3 4 5 6 7; do
  sketchybar --add item timew.day.$d popup.timew --set timew.day.$d "${TW_DATA[@]}"
done
