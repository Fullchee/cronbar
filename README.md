# Cronbar

A macOS menu bar app for your launchd jobs. It lists the jobs in `~/Library/LaunchAgents` with their schedule, load state and last exit code.

## Install

Needs macOS 14 or later, on an Apple silicon or Intel Mac.

1. Download **Cronbar.zip** from the [latest release](https://github.com/Fullchee/cronbar/releases/latest).
2. Double-click the zip to unzip it.
3. Drag **Cronbar.app** into your **Applications** folder.
4. Open **Cronbar.app**. macOS blocks it the first time because it isn't notarized by Apple. Allow it once:
   - **macOS 15 or later**: click **Done** on the warning. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to "Cronbar was blocked". Enter your password, then click **Open Anyway** again.
   - **macOS 14**: right-click **Cronbar.app** in Applications, choose **Open**, then click **Open**.
5. Look for the clock icon in the menu bar. Cronbar has no window or Dock icon.
6. Optional: click the clock and tick **Open at Login** so it starts with your Mac.

**Prefer the terminal?** After step 3, run this instead of step 4:

```sh
xattr -dr com.apple.quarantine /Applications/Cronbar.app && open /Applications/Cronbar.app
```

### Can't find the icon?

- **Menu bar manager**: Bartender, Ice or Thaw may put new icons in their hidden section. Move Cronbar out of it.
- **Crowded menu bar**: on a Mac with a notch, icons that don't fit get hidden behind it. Quit another menu bar app, or ⌘-drag icons to make room.
- **macOS 26 or later**: check **System Settings → Menu Bar** and make sure Cronbar is allowed.
- **Is it running?** Open Activity Monitor and search for Cronbar.

### Update or uninstall

- **Update**: quit Cronbar from its menu, then repeat steps 1–4 and replace the old app.
- **Uninstall**: quit Cronbar from its menu and drag **Cronbar.app** to the Trash. Cronbar doesn't change your jobs or plists.

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
