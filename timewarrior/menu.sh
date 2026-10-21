#!/usr/bin/env bash
# Fills the menu: status, pause / stop, categories with today's time, summary, week chart.
source "$CONFIG_DIR/plugins/timewarrior/lib.sh"
tw_load_tags
tw_state

RANGE="$(cat "$TW_RANGE" 2>/dev/null)"
case "$RANGE" in week|month) ;; *) RANGE=day ;; esac
CHART="$(cat "$TW_CHART" 2>/dev/null)"

args=()
case "$TW_STATUS" in
  tracking)
    args+=(--set timew.now icon= icon.color=$TW_ACTIVE label="${TW_TAG:0:14}  $(tw_hms "$TW_SECS")"
           --set timew.pause drawing=on icon= label="Pause"
           --set timew.stop drawing=on) ;;
  paused)
    args+=(--set timew.now icon= icon.color=$TW_PAUSED label="${TW_TAG:0:14}  $(tw_hms "$TW_SECS")"
           --set timew.pause drawing=on icon= label="Resume"
           --set timew.stop drawing=on) ;;
  *)
    args+=(--set timew.now icon= icon.color=$TW_DIM label="Not tracking"
           --set timew.pause drawing=off
           --set timew.stop drawing=off) ;;
esac

case "$RANGE" in
  day)   args+=(--set timew.sumhead label="Today       > week") ;;
  week)  args+=(--set timew.sumhead label="This week   > month") ;;
  month) args+=(--set timew.sumhead label="This month  > today") ;;
esac

row=0; day=0
while IFS=$'\t' read -r KIND A B; do
  case "$KIND" in
    cat)    # A = position in TW_TAGS, B = label
      if [ "$TW_STATUS" = "tracking" ] && [ "${TW_TAG_LIST[$((A - 1))]}" = "$TW_TAG" ]; then
        args+=(--set timew.tag.$A icon= icon.color=$TW_ACTIVE label="$B" label.color=$TW_ACTIVE)
      else
        args+=(--set timew.tag.$A icon= icon.color=$TW_DIM label="$B" label.color=$TW_TEXT)
      fi ;;
    row|total)
      row=$((row + 1))
      [ "$row" -gt 12 ] && continue
      if [ "$KIND" = "total" ]; then W=Bold; C=$TW_TEXT; else W=Regular; C=$TW_DIM; fi
      args+=(--set timew.row.$row drawing=on label="$A" label.color=$C label.font="$TW_FONT Mono:$W:12.0") ;;
    week)
      if [ "$CHART" = "hidden" ]; then
        args+=(--set timew.charthead label="Week chart  (show)")
      else
        args+=(--set timew.charthead label="Week   $(tw_hms "$A")  (hide)")
      fi ;;
    past|today|future)
      day=$((day + 1))
      if [ "$CHART" = "hidden" ]; then args+=(--set timew.day.$day drawing=off); continue; fi
      case "$KIND" in
        today)  C=$TW_ACCENT; W=Bold ;;
        future) C=$TW_DIM;    W=Regular ;;
        *)      C=$TW_TEXT;   W=Regular ;;
      esac
      args+=(--set timew.day.$day drawing=on label="$A" label.color=$C label.font="$TW_FONT Mono:$W:12.0") ;;
  esac
done <<< "$("$TW_PY" "$TW_STATS" menu "$RANGE" 2>/dev/null)"

while [ "$row" -lt 12 ]; do
  row=$((row + 1))
  args+=(--set timew.row.$row drawing=off)
done

sketchybar "${args[@]}"
