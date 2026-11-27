#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  PLISTS="$ROOT/test/fixtures/plists"
  PRINTS="$ROOT/test/fixtures/launchctl"
  # shellcheck source=plugin/cronbar.1m.sh
  source "$ROOT/plugin/cronbar.1m.sh"
}

# --- schedule_words ---

@test "daily calendar entry" {
  [ "$(schedule_words "$PLISTS/daily.plist")" = "daily 09:00" ]
}

@test "minute-only calendar entry is hourly" {
  [ "$(schedule_words "$PLISTS/hourly.plist")" = "hourly at :05" ]
}

@test "weekday calendar entry is weekly" {
  [ "$(schedule_words "$PLISTS/weekly.plist")" = "weekly Mon 08:30" ]
}

@test "day calendar entry is monthly" {
  [ "$(schedule_words "$PLISTS/monthly.plist")" = "monthly day 1 06:00" ]
}

@test "month calendar entry is yearly" {
  [ "$(schedule_words "$PLISTS/yearly.plist")" = "yearly Dec 25 07:00" ]
}

@test "empty calendar dict runs every minute" {
  [ "$(schedule_words "$PLISTS/every-minute.plist")" = "every minute" ]
}

@test "calendar array of the same kind collapses to a range" {
  [ "$(schedule_words "$PLISTS/calendar-array.plist")" = "daily 09:15 … 17:15 (3×)" ]
}

@test "calendar array of mixed kinds names the first" {
  [ "$(schedule_words "$PLISTS/calendar-mixed.plist")" = "2 schedules, first: daily 09:00" ]
}

@test "StartInterval in minutes" {
  [ "$(schedule_words "$PLISTS/interval-30m.plist")" = "every 30 min" ]
}

@test "StartInterval in hours" {
  [ "$(schedule_words "$PLISTS/interval-2h.plist")" = "every 2 h" ]
}

@test "StartInterval in odd seconds" {
  [ "$(schedule_words "$PLISTS/interval-90s.plist")" = "every 90 s" ]
}

@test "seconds_to_words covers days and single units" {
  [ "$(seconds_to_words 86400)" = "every day" ]
  [ "$(seconds_to_words 172800)" = "every 2 days" ]
  [ "$(seconds_to_words 3600)" = "every hour" ]
}

@test "RunAtLoad only means at login" {
  [ "$(schedule_words "$PLISTS/run-at-load.plist")" = "at login" ]
}

@test "KeepAlive means always running" {
  [ "$(schedule_words "$PLISTS/keep-alive.plist")" = "always running" ]
}

@test "WatchPaths means on file change" {
  [ "$(schedule_words "$PLISTS/watch.plist")" = "on file change" ]
}

@test "no trigger means on demand" {
  [ "$(schedule_words "$PLISTS/on-demand.plist")" = "on demand" ]
}

# --- parse_launchctl_print ---

@test "loaded job with exit 0" {
  [ "$(parse_launchctl_print <"$PRINTS/loaded-exit0.txt")" = "yes 0" ]
}

@test "loaded job that never ran" {
  [ "$(parse_launchctl_print <"$PRINTS/loaded-never.txt")" = "yes never" ]
}

@test "exit code with a description keeps the number" {
  [ "$(parse_launchctl_print <"$PRINTS/loaded-exit78.txt")" = "yes 78" ]
}

@test "killed by a signal with no exit code" {
  [ "$(parse_launchctl_print <"$PRINTS/loaded-signal.txt")" = "yes signal" ]
}

@test "service not found is not loaded" {
  [ "$(parse_launchctl_print <"$PRINTS/not-found.txt")" = "no ?" ]
}

@test "empty output is not loaded" {
  [ "$(parse_launchctl_print </dev/null)" = "no ?" ]
}

@test "nested blocks do not count as the job's exit code" {
  local out
  out=$(printf 'gui/501/x = {\n\tevent triggers = {\n\t\tfoo = {\n\t\t\tstate = active\n\t\t}\n\t}\n\tlast exit code = 1\n}\n' | parse_launchctl_print)
  [ "$out" = "yes 1" ]
}

# --- skip list and failures ---

@test "vendor prefixes are skipped" {
  is_skipped com.apple.something
  is_skipped homebrew.mxcl.postgresql
  ! is_skipped com.example.daily
}

@test "only real non-zero exits are failures" {
  is_failure 1
  is_failure signal
  ! is_failure 0
  ! is_failure never
  ! is_failure "?"
}

# --- full menu, with a fake launchctl ---

fake_launchctl() {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat >"$BATS_TEST_TMPDIR/bin/launchctl" <<EOF
#!/usr/bin/env bash
case "\$2" in
  */com.example.daily) cat "$PRINTS/loaded-exit78.txt" ;;
  */com.example.interval-30m) cat "$PRINTS/loaded-exit0.txt" ;;
  *) cat "$PRINTS/not-found.txt"; exit 113 ;;
esac
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/launchctl"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "menu counts failures and skips vendor agents" {
  fake_launchctl
  AGENTS_DIR=$PLISTS
  run main
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "1 | sfimage=clock.badge.exclamationmark color=red" ]
  [[ $output == *"com.example.daily  ·  on · daily 09:00 · exit 78 | sfimage=xmark.octagon.fill"* ]]
  [[ $output == *"com.example.interval-30m  ·  on · every 30 min · exit 0 | sfimage=checkmark.circle"* ]]
  [[ $output == *"com.example.hourly  ·  off · hourly at :05 · not loaded | sfimage=pause.circle"* ]]
  [[ $output != *"com.apple.something"* ]]
}

@test "menu actions for a loaded job" {
  fake_launchctl
  AGENTS_DIR=$PLISTS
  run main
  [[ $output == *"--Run now | sfimage=play.fill bash=/bin/launchctl param1=kickstart param2=$DOMAIN/com.example.daily terminal=false refresh=true"* ]]
  [[ $output == *"--Turn off | sfimage=stop.fill bash=/bin/launchctl param1=bootout param2=$DOMAIN param3=\"$PLISTS/daily.plist\""* ]]
  [[ $output == *"--Open log | sfimage=doc.text bash=/usr/bin/open param1=\"/tmp/example out.log\""* ]]
  [[ $output == *"--Open error log | sfimage=doc.text.fill bash=/usr/bin/open param1=\"/tmp/example-err.log\""* ]]
  [[ $output == *"--Reveal plist in Finder | sfimage=folder bash=/usr/bin/open param1=-R param2=\"$PLISTS/daily.plist\""* ]]
}

@test "unloaded job offers Turn on" {
  fake_launchctl
  AGENTS_DIR=$PLISTS
  run main
  [[ $output == *"--Turn on | sfimage=power bash=/bin/launchctl param1=bootstrap param2=$DOMAIN param3=\"$PLISTS/hourly.plist\""* ]]
}

@test "all-green title shows a check" {
  fake_launchctl
  AGENTS_DIR=$BATS_TEST_TMPDIR/agents
  mkdir -p "$AGENTS_DIR"
  cp "$PLISTS/interval-30m.plist" "$AGENTS_DIR/"
  run main
  [ "${lines[0]}" = "| sfimage=clock.badge.checkmark" ]
}

@test "empty agents folder says so" {
  AGENTS_DIR=$BATS_TEST_TMPDIR/empty
  mkdir -p "$AGENTS_DIR"
  run main
  [[ $output == *"No jobs in $AGENTS_DIR | disabled=true"* ]]
}

@test "menu text drops the pipe character" {
  [ "$(menu_text 'a|b')" = "a¦b" ]
}
