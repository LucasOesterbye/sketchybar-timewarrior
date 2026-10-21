#!/usr/bin/env python3
"""Reads Timewarrior for sketchybar-timewarrior (needs the TIMEW and TW_TAGS environment variables).
   active        "<start epoch><TAB><category>" of the running interval, or nothing
   today         seconds tracked today
   menu <range>  menu lines: categories with today's time, summary for day|week|month, week chart
"""
import calendar
import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone

TIMEW = os.environ.get("TIMEW", "timew")
NOW = datetime.now(timezone.utc)
TODAY = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)  # local midnight (naive)
MONDAY = TODAY - timedelta(days=TODAY.weekday())
FIRST = TODAY.replace(day=1)
DAYS = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
BAR_WIDTH = 11
EIGHTHS = ["", "\u258f", "\u258e", "\u258d", "\u258c", "\u258b", "\u258a", "\u2589"]
FULL, DOT = "\u2588", "\u00b7"


def aware(naive):
    """Naive local time -> timezone-aware (handles daylight saving)."""
    return naive.astimezone()


def export(since):
    """Intervals from `since` (naive local date) until tomorrow."""
    until = TODAY + timedelta(days=1)
    cmd = [TIMEW, "export", "from", since.strftime("%Y-%m-%d"), "to", until.strftime("%Y-%m-%d")]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    try:
        return json.loads(out or "[]")
    except ValueError:
        return []


def parse(stamp):
    return datetime.strptime(stamp, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)


def category(interval):
    return " ".join(interval.get("tags") or ["untagged"])


def intervals(data):
    for i in data:
        end = parse(i["end"]) if "end" in i else NOW
        yield parse(i["start"]), end, category(i)


def per_category(data, since):
    since, totals = aware(since), {}
    for start, end, tag in intervals(data):
        secs = (end - max(start, since)).total_seconds()
        if secs > 0:
            totals[tag] = totals.get(tag, 0) + secs
    return totals


def hms(secs):
    secs = int(secs)
    return "%d:%02d:%02d" % (secs // 3600, secs % 3600 // 60, secs % 60)


def line(name, secs):
    return "%-14s %9s" % (name[:14], hms(secs))


def menu(span):
    data = export(min(MONDAY, FIRST))

    today = per_category(data, TODAY)
    tags = [t.strip() for t in os.environ.get("TW_TAGS", "").split(";") if t.strip()]
    for n, tag in enumerate(tags, 1):
        secs = today.get(tag, 0)
        print("cat\t%d\t%s" % (n, line(tag, secs) if secs >= 1 else tag[:14]))

    totals = per_category(data, {"week": MONDAY, "month": FIRST}.get(span, TODAY))
    if not totals:
        print("row\tNothing tracked yet")
    ranked = sorted(totals.items(), key=lambda x: -x[1])
    if len(ranked) > 10:                                  # the menu has 12 rows; keep room for Total
        ranked = ranked[:9] + [("Other (%d)" % (len(ranked) - 9), sum(s for _, s in ranked[9:]))]
    for tag, secs in ranked:
        print("row\t" + line(tag, secs))
    if totals:
        print("total\t" + line("Total", sum(totals.values())))

    edges = [aware(MONDAY + timedelta(days=d)) for d in range(8)]
    week = [0.0] * 7
    for start, end, _ in intervals(data):
        for d in range(7):
            overlap = (min(end, edges[d + 1]) - max(start, edges[d])).total_seconds()
            if overlap > 0:
                week[d] += overlap
    print("week\t%d" % sum(week))
    scale = max(max(week), 3600)
    for d, name in enumerate(DAYS):
        if d > TODAY.weekday():
            print("future\t%s %s" % (name, DOT))
            continue
        units = int(week[d] / scale * BAR_WIDTH * 8)
        bar = FULL * (units // 8) + EIGHTHS[units % 8] or (EIGHTHS[1] if week[d] else "")
        kind = "today" if d == TODAY.weekday() else "past"
        print("%s\t%s %-*s %8s" % (kind, name, BAR_WIDTH, bar, hms(week[d]) if week[d] else "-"))


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "today"
    if mode == "active":
        running = [i for i in export(TODAY) if "end" not in i]
        if running:
            last = running[-1]
            print("%d\t%s" % (calendar.timegm(parse(last["start"]).timetuple()), category(last)))
    elif mode == "today":
        print(int(sum(per_category(export(TODAY), TODAY).values())))
    elif mode == "menu":
        menu(sys.argv[2] if len(sys.argv) > 2 else "day")


main()
