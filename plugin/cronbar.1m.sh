#!/usr/bin/env bash
# <xbar.title>Cronbar</xbar.title>
# <xbar.desc>Shows your launchd jobs from ~/Library/LaunchAgents: schedule, load state, last exit code.</xbar.desc>
# <xbar.dependencies>bash,plutil,launchctl</xbar.dependencies>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideDisappearPlugin>true</swiftbar.hideDisappearPlugin>

# Jobs whose label starts with one of these prefixes are hidden.
SKIP_PREFIXES=(
  com.apple.
  com.google.
  com.microsoft.
  com.github.facebook.
  com.adobe.
  com.dropbox.
  com.spotify.
  com.docker.
  com.jetbrains.
  homebrew.
  org.mozilla.
  us.zoom.
)

AGENTS_DIR="${CRONBAR_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
DOMAIN="gui/$(id -u)"

# Stays compatible with macOS's stock bash 3.2: SwiftBar may run it instead of Homebrew bash.

plist_value() {
  plutil -extract "$2" raw -o - "$1" 2>/dev/null
}

plist_type() {
  plutil -type "$2" "$1" 2>/dev/null
}

is_skipped() {
  local label=$1 prefix
  for prefix in "${SKIP_PREFIXES[@]}"; do
    [[ $label == "$prefix"* ]] && return 0
  done
  return 1
}

seconds_to_words() {
  local s=$1
  if ((s > 0 && s % 86400 == 0)); then
    (( s == 86400 )) && echo "every day" || echo "every $((s / 86400)) days"
  elif ((s > 0 && s % 3600 == 0)); then
    (( s == 3600 )) && echo "every hour" || echo "every $((s / 3600)) h"
  elif ((s > 0 && s % 60 == 0)); then
    echo "every $((s / 60)) min"
  else
    echo "every $s s"
  fi
}

weekday_name() {
  case $1 in
    0 | 7) echo Sun ;; 1) echo Mon ;; 2) echo Tue ;; 3) echo Wed ;;
    4) echo Thu ;; 5) echo Fri ;; 6) echo Sat ;; *) echo "day$1" ;;
  esac
}

month_name() {
  case $1 in
    1) echo Jan ;; 2) echo Feb ;; 3) echo Mar ;; 4) echo Apr ;; 5) echo May ;; 6) echo Jun ;;
    7) echo Jul ;; 8) echo Aug ;; 9) echo Sep ;; 10) echo Oct ;; 11) echo Nov ;; 12) echo Dec ;;
    *) echo "month$1" ;;
  esac
}

# One StartCalendarInterval dict, given as key path prefix ("StartCalendarInterval" or "StartCalendarInterval.2").
calendar_entry_words() {
  local plist=$1 path=$2 minute hour day weekday month time
  minute=$(plist_value "$plist" "$path.Minute")
  hour=$(plist_value "$plist" "$path.Hour")
  day=$(plist_value "$plist" "$path.Day")
  weekday=$(plist_value "$plist" "$path.Weekday")
  month=$(plist_value "$plist" "$path.Month")

  if [[ -n $hour && -n $minute ]]; then
    time=$(printf '%02d:%02d' "$hour" "$minute")
  elif [[ -n $hour ]]; then
    time=$(printf 'each min of %02d:xx' "$hour")
  elif [[ -n $minute ]]; then
    time=$(printf ':%02d' "$minute")
  fi

  if [[ -n $month ]]; then
    echo "yearly $(month_name "$month")${day:+ $day}${weekday:+ $(weekday_name "$weekday")}${time:+ $time}"
  elif [[ -n $day ]]; then
    echo "monthly day $day${weekday:+ $(weekday_name "$weekday")}${time:+ $time}"
  elif [[ -n $weekday ]]; then
    echo "weekly $(weekday_name "$weekday")${time:+ $time}"
  elif [[ -n $hour ]]; then
    echo "daily $time"
  elif [[ -n $minute ]]; then
    echo "hourly at $time"
  else
    echo "every minute"
  fi
}

calendar_words() {
  local plist=$1 count i entry first="" last="" kind same_kind=1
  if [[ $(plist_type "$plist" StartCalendarInterval) != array ]]; then
    calendar_entry_words "$plist" StartCalendarInterval
    return
  fi
  count=$(plist_value "$plist" StartCalendarInterval)
  ((count == 0)) && return
  for ((i = 0; i < count; i++)); do
    entry=$(calendar_entry_words "$plist" "StartCalendarInterval.$i")
    [[ -z $first ]] && first=$entry && kind=${entry%% *}
    [[ ${entry%% *} != "$kind" ]] && same_kind=0
    last=$entry
  done
  if ((count == 1)); then
    echo "$first"
  elif ((same_kind)); then
    echo "$first … ${last#* } (${count}×)"
  else
    echo "$count schedules, first: $first"
  fi
}

schedule_words() {
  local plist=$1 interval
  if [[ -n $(plist_type "$plist" StartCalendarInterval) ]]; then
    calendar_words "$plist"
    return
  fi
  interval=$(plist_value "$plist" StartInterval)
  if [[ -n $interval ]]; then
    seconds_to_words "$interval"
  elif [[ -n $(plist_type "$plist" WatchPaths) || -n $(plist_type "$plist" QueueDirectories) ]]; then
    echo "on file change"
  elif [[ -n $(plist_type "$plist" KeepAlive) && $(plist_value "$plist" KeepAlive) != false ]]; then
    echo "always running"
  elif [[ $(plist_value "$plist" RunAtLoad) == true ]]; then
    echo "at login"
  else
    echo "on demand"
  fi
}

# Reads `launchctl print` output on stdin; prints "<loaded> <exit>".
# loaded: yes|no. exit: a number, "never" or "?". The format is undocumented, so only the first match counts.
parse_launchctl_print() {
  local output loaded=no exit_code="?" line value
  output=$(cat)
  if grep -qE '^[^[:space:]].* = \{' <<<"$output"; then
    loaded=yes
  fi
  line=$(grep -m1 -E '^[[:space:]]*last exit code = ' <<<"$output")
  if [[ -n $line ]]; then
    value=${line#*= }
    if [[ $value == *"never exited"* ]]; then
      exit_code=never
    elif [[ $value =~ ^(-?[0-9]+) ]]; then
      exit_code=${BASH_REMATCH[1]}
    fi
  elif [[ $loaded == yes ]] && grep -qE '^[[:space:]]*last terminating signal = ' <<<"$output"; then
    exit_code=signal
  elif [[ $loaded == yes ]]; then
    exit_code=never
  fi
  echo "$loaded $exit_code"
}

job_status() {
  launchctl print "$DOMAIN/$1" 2>&1 | parse_launchctl_print
}

is_failure() {
  [[ $1 != 0 && $1 != never && $1 != "?" ]]
}

# SwiftBar splits on "|", so keep it out of menu text.
menu_text() {
  local text=${1//|/¦}
  echo "$text"
}

print_job() {
  local plist=$1 label=$2 schedule=$3 loaded=$4 exit_code=$5 icon state exit_words out err
  if [[ $loaded == no ]]; then
    icon="pause.circle" state="off"
  elif is_failure "$exit_code"; then
    icon="xmark.octagon.fill" state="on"
  else
    icon="checkmark.circle" state="on"
  fi
  case $exit_code in
    never) exit_words="not run yet" ;;
    "?") exit_words="exit unknown" ;;
    signal) exit_words="killed by signal" ;;
    *) exit_words="exit $exit_code" ;;
  esac
  [[ $loaded == no ]] && exit_words="not loaded"

  echo "$(menu_text "$label  ·  $state · $schedule · $exit_words") | sfimage=$icon"
  echo "--Run now | sfimage=play.fill bash=/bin/launchctl param1=kickstart param2=$DOMAIN/$label terminal=false refresh=true"
  if [[ $loaded == yes ]]; then
    echo "--Turn off | sfimage=stop.fill bash=/bin/launchctl param1=bootout param2=$DOMAIN param3=\"$plist\" terminal=false refresh=true"
  else
    echo "--Turn on | sfimage=power bash=/bin/launchctl param1=bootstrap param2=$DOMAIN param3=\"$plist\" terminal=false refresh=true"
  fi
  out=$(plist_value "$plist" StandardOutPath)
  err=$(plist_value "$plist" StandardErrorPath)
  if [[ -n $out ]]; then
    echo "--Open log | sfimage=doc.text bash=/usr/bin/open param1=\"$out\" terminal=false"
  fi
  if [[ -n $err && $err != "$out" ]]; then
    echo "--Open error log | sfimage=doc.text.fill bash=/usr/bin/open param1=\"$err\" terminal=false"
  fi
  echo "--Reveal plist in Finder | sfimage=folder bash=/usr/bin/open param1=-R param2=\"$plist\" terminal=false"
}

main() {
  local plist label status loaded exit_code failures=0 body="" shopt_nullglob
  shopt_nullglob=$(shopt -p nullglob)
  shopt -s nullglob
  for plist in "$AGENTS_DIR"/*.plist; do
    label=$(plist_value "$plist" Label)
    [[ -z $label ]] && continue
    is_skipped "$label" && continue
    status=$(job_status "$label")
    loaded=${status%% *}
    exit_code=${status#* }
    [[ $loaded == yes ]] && is_failure "$exit_code" && failures=$((failures + 1))
    body+=$(print_job "$plist" "$label" "$(schedule_words "$plist")" "$loaded" "$exit_code")$'\n'
  done
  eval "$shopt_nullglob"

  if ((failures > 0)); then
    echo "$failures | sfimage=clock.badge.exclamationmark color=red"
  else
    echo "| sfimage=clock.badge.checkmark"
  fi
  echo "---"
  if [[ -z $body ]]; then
    echo "No jobs in $AGENTS_DIR | disabled=true"
  else
    printf '%s' "$body"
  fi
  echo "---"
  echo "Open LaunchAgents folder | bash=/usr/bin/open param1=\"$AGENTS_DIR\" terminal=false"
  echo "Refresh | refresh=true"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main
fi
