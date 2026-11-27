# Cronbar

A macOS menu bar app for your launchd jobs. It lists the jobs in `~/Library/LaunchAgents` with their schedule, load state and last exit code.

## Install

1. Download **Cronbar.zip** from the [latest release](https://github.com/Fullchee/cronbar/releases/latest).
2. Unzip it and move **Cronbar.app** to `/Applications`.
3. First launch: right-click **Cronbar.app** → **Open** → **Open**. The app isn't notarized, so macOS asks once.
4. Optional: tick **Open at Login** in the Cronbar menu.

Needs macOS 14 or later.

## The menu

**Menu bar icon**: a clock with a check when all jobs are fine. A number shows how many loaded jobs last exited non-zero.

**One row per job**: `label · on/off · schedule · last exit`, for example `com.me.backup · on · daily 09:00 · exit 0`.

- **Icons**: check circle for fine, red octagon for a failed last run, pause circle for not loaded.
- **Schedule words**: `daily 09:00`, `hourly at :05`, `weekly Mon 08:30`, `monthly day 1 06:00`, `every 30 min`, `at login`, `always running`, `on file change`, `on demand`. Several calendar entries collapse to `daily 09:15 … 17:15 (9×)`.
- **Last exit**: `exit 0`, `exit 78`, `not run yet`, `killed by signal`, or `not loaded`.

**Submenu per job**:

| Item | What it does |
|---|---|
| Run Now | `launchctl kickstart gui/$UID/<label>` |
| Turn Off | `launchctl bootout gui/$UID <plist>` (shown when loaded) |
| Turn On | `launchctl bootstrap gui/$UID <plist>` (shown when not loaded) |
| Open Log | Opens `StandardOutPath` |
| Open Error Log | Opens `StandardErrorPath`, when it differs from the out log |
| Reveal Plist in Finder | Selects the plist in Finder |

Turning a job on or off only loads or unloads it for this login session. It doesn't edit the plist, so a job turned off loads again at next login.

The menu refreshes every minute. The bottom of the menu has **Open LaunchAgents Folder**, **Refresh**, **Open at Login** and **Quit**.

## Hidden jobs

Vendor agents are hidden: labels starting `com.apple.`, `com.google.`, `homebrew.` and others. See `hiddenPrefixes` in `Sources/CronbarCore/Job.swift`.

## Develop

- **Tests**: `swift test`
- **Run**: `swift run Cronbar`
- **Build the app**: `scripts/build-app.sh 1.2.3` writes `dist/Cronbar.app` and `dist/Cronbar.zip`.
- **Release**: push a `v*` tag. GitHub Actions tests, builds and publishes the zip.

`CronbarCore` holds the parsing and is fully tested. The `Cronbar` target is the SwiftUI menu.
