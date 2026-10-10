# Mac Usage

A native, local-only macOS companion to [Phone Usage](https://github.com/jerrylusato/phone-usage-tracker).
Tracks active foreground application time, with a dashboard, Monday–Sunday charts, history,
JSON export, manual monthly deletion, and daily/weekly notification summaries.

## Build and run

Requires macOS 13+ and Swift 5.10 or newer. Building needs Xcode Command Line Tools;
`swift test` also needs a full Xcode installation providing XCTest.

```sh
swift test
./scripts/build-app.sh
open "dist/Mac Usage.app"
```

Copy `dist/Mac Usage.app` to `/Applications` for regular use. Open **Mac Usage → Settings**
to enable launch at login, allow notifications, and choose the idle timeout. Closing the
dashboard keeps tracking running in the menu bar; **Quit Mac Usage** stops it.
The build produces an ad-hoc signed app for local use, without Developer ID notarization.
GitHub Actions tests and builds an app artifact for its runner's architecture.

## What is counted

The previous foreground app accrues time between five-second samples and app activation
notifications. Counting stops after two minutes without input by default (configurable to
one or five minutes), on display/system sleep, when the user session becomes inactive, or
when paused. The grace period before the idle threshold counts as active time, so passive
reading beyond that threshold is excluded. App sessions start on app switches or after a
tracking interruption; they are not window changes or individual clicks.

Polling gaps over 12 seconds are discarded. There is no historical macOS Screen Time import,
no backfill while the app is closed, and no tracking before first launch. Time is attributed
across day/month boundaries using the current local calendar and time zone. This measures
active app time, which can differ from Apple's Screen Time and from physical display-on time.
Short switches can be bounded by event/poll timing. Browser usage is grouped by browser app,
without individual website tracking.

## History and privacy

The app records only app name, bundle identifier, session ID, and start/end timestamps.
It does not inspect app contents, window titles, websites, clipboard, or keystrokes, and
contains no networking or analytics code. No Accessibility or Screen Recording access is
requested. macOS input idle counters are used without installing a keyboard event tap.

History is stored in `~/Library/Application Support/MacUsageTracker/sessions.json`, written
atomically every 30 seconds and when pausing, sleeping, or quitting. A crash can lose the
latest unsaved interval. An unreadable history file stops tracking to avoid overwriting it.
History is retained until you delete a month from the **History** view; deletion requires
confirmation. Export saves all recorded sessions through the system file picker. Removing
the app does not remove its Application Support data. Exported data is personal: do not commit it.

## Reports

Allow notifications in Settings. Weekly reports are enabled by default and cover the previous
complete Monday–Sunday week. Optional daily reports cover yesterday. Both are checked after
09:00 local time while the app is running and awake. A daily report can arrive later the same
day; weekly delivery requires the app to run on Monday after 09:00. Missed days are not replayed.
The notification lists total active time and the top three apps. Report delivery markers,
idle timeout, and report preferences live in macOS UserDefaults. Launch at login uses
`SMAppService`; macOS may require approval under System Settings → General → Login Items.

## Source layout and verification

- `Sources/UsageCore`: recording and calendar aggregation without UI dependencies.
- `Sources/MacUsageTracker`: SwiftUI dashboard, menu bar, collection, storage, and reports.
- `Tests/UsageCoreTests`: idle, gap, app-switch, and calendar-boundary regression tests.
- `scripts/build-app.sh`: release build, app bundle, and ad-hoc signing.

```sh
swift test
./scripts/build-app.sh
codesign --verify --strict "dist/Mac Usage.app"
```
