# Cronbar

SwiftBar menu bar plugin for macOS launchd jobs. It lists your jobs in `~/Library/LaunchAgents` with their schedule, load state and last exit code.

## Install

1. Install SwiftBar: `brew install --cask swiftbar`
2. Open SwiftBar and pick a plugin folder. Either:
   - point it at this repo's `plugin/` folder, or
   - symlink the script into your existing plugin folder:
     `ln -s "$PWD/plugin/cronbar.1m.sh" ~/path/to/swiftbar-plugins/`
3. The menu refreshes every minute (the `1m` in the filename).

## The menu

**Title**: a clock icon. A red number shows how many loaded jobs last exited non-zero. A check means all are fine.

**One row per job**: `label · on/off · schedule · last exit`, for example `com.me.backup · on · daily 09:00 · exit 0`.

- **Icons**: ✓ circle for fine, red octagon for a failed last run, pause circle for not loaded.
- **Schedule words**: `daily 09:00`, `hourly at :05`, `weekly Mon 08:30`, `monthly day 1 06:00`, `every 30 min`, `at login`, `always running`, `on file change`, `on demand`. Several calendar entries collapse to `daily 09:15 … 17:15 (9×)`.
- **Last exit**: `exit 0`, `exit 78`, `not run yet`, `killed by signal`, or `not loaded`.

**Submenu per job**:

| Item | What it does |
|---|---|
| Run now | `launchctl kickstart gui/$UID/<label>` |
| Turn off | `launchctl bootout gui/$UID <plist>` (shown when loaded) |
| Turn on | `launchctl bootstrap gui/$UID <plist>` (shown when not loaded) |
| Open log | Opens `StandardOutPath` |
| Open error log | Opens `StandardErrorPath`, when it differs from the out log |
| Reveal plist in Finder | `open -R <plist>` |

Turning a job on or off only loads or unloads it for this login session. It does not edit the plist, so a job turned off loads again at next login.

The bottom of the menu has **Open LaunchAgents folder** and **Refresh**.

## Hidden jobs

Vendor agents are hidden: labels starting `com.apple.`, `com.google.`, `homebrew.` and others. Edit `SKIP_PREFIXES` at the top of `plugin/cronbar.1m.sh` to change the list.

## Develop

- **Tests**: `bats test/` (install with `brew install bats-core`).
- **Lint**: `shellcheck plugin/cronbar.1m.sh`
- **Preview the menu text**: `./plugin/cronbar.1m.sh`
- **Point at another folder**: `CRONBAR_AGENTS_DIR=test/fixtures/plists ./plugin/cronbar.1m.sh`

The script stays compatible with macOS's stock bash 3.2, which SwiftBar may use.
