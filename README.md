# HabitLedger

A habit tracker that lives in the macOS menu bar. No dock icon, no window to
manage — a flame in the status bar that fills in when you've logged everything
for the day.

**Developer:** Nav Virdi — [Liberated.Studio](https://liberated.studio) — [nav@Liberated.Studio](mailto:nav@Liberated.Studio)

---

## How it works

Click the flame to open the panel and log the day. Right-click it for Add New
Habit, Settings, About and Quit.

The icon is the whole status display: **filled** when every habit scheduled for
today has been logged, **hollow** when something is outstanding.

## Habits

Every habit has a **type** and a **goal**.

| Type | What you record |
|---|---|
| **Binary** | Yes or No — a fact about the day |
| **Numerical** | A number, optionally against a target |

| Goal | What counts as success |
|---|---|
| **Adopt** | Binary: Yes. Numerical: at or above the target (or above zero with no target). |
| **Quit** | Binary: No. Numerical: at or below the target (or exactly zero with no target). |

So "Meditation" is a binary adopt habit, and "Alcohol, target 2, quit" succeeds
on any day you record two drinks or fewer.

The type is locked once a habit has entries — there is no conversion between
binary and numerical, so the app won't let you strand your history.

## Schedules

- **Daily** — every day counts.
- **Specific weekdays** — pick the days.
- **N times per week** — hit the count, any days you like.

Days a habit isn't scheduled are **skipped**: they don't break a streak, don't
extend one, and don't count in the statistics.

## Streaks, and what breaks them

This is the part most habit trackers get wrong, so it's worth stating plainly.

**For binary habits, not logging a day is a silent success.** The Yes/No control
records a fact, and a day you never touched is a day you made no claim about.
Streaks break on **confessed failures** — the days you said No to a habit you
meant to adopt — not on days you forgot to open the app.

**For numerical habits, not logging a day is a failure.** An unrecorded value
counts as zero, because "I read for zero minutes" is the honest reading of a
blank.

**Times-per-week habits are counted in weeks, not days.** A week is met once you
have N *explicitly logged* successes — silent successes don't fill the quota.
The current week counts as soon as you meet it, and while it's still achievable
it neither counts nor breaks. These streaks show a "w" suffix: 🔥 3w means three
weeks.

Streaks look back up to a year.

## Progress

Open any habit's progress view:

- **Binary** — a monthly calendar with four states per day: logged success,
  failure, unlogged, and skipped. **Click any day to cycle it** through unlogged
  → Yes → No, so you can fill in a day you missed. Below it, a 52-week heatmap
  of the year.
- **Numerical** — success rate (when a target is set) and a 30-day average, plus
  a weekly bar chart. **Click a bar to back-log** that day through a stepper.

You can only navigate back as far as the habit's own start date.

## Settings

- **Launch at login** (via macOS's `SMAppService`)
- **Accent colour** — seven options: System, Sage, Slate, Clay, Rose, Plum, Ochre.
  "System" follows your macOS accent.
- **Daily reminder** — one repeating notification at a time you choose. macOS
  asks for notification permission the first time you enable it.
- **Export JSON** — the complete data file.
- **Export CSV** — one row per entry: `habit,type,goal,date,value`.
- **Import JSON** — replaces everything, after a confirmation.

## Your data

HabitLedger is **sandboxed** and makes **no network requests of any kind**.
Everything stays on your Mac.

Data is written to `Application Support/HabitLedger/` inside the app's sandbox
container:

```
~/Library/Containers/studio.liberated.HabitLedger/Data/Library/Application Support/HabitLedger/
    habit_data.json
    habit_data_backup.json
```

The backup is rewritten before every save, and is restored automatically if the
main file is ever unreadable. Imported and loaded data is sanitised — future-dated
entries and values that don't match the habit's type are stripped, and negative
numbers are clamped.

**The data format is forward-only by design.** There are no migration shims and
no legacy decode paths. A data file written by a version that predates a field
will fail to decode rather than be silently repaired; the app reports the error
once and starts from defaults. Keep your JSON exports.

On first run you get four example habits — Meditation, Exercise, Alcohol and
Reading — to delete or keep.

## Requirements

- **macOS 15.6** or later
- Universal binary — Apple Silicon and Intel

## Building

1. Open `HabitLedger.xcodeproj` in Xcode. Full Xcode is required, not just the
   Command Line Tools.
2. **Set your own signing team** under Signing & Capabilities. This project ships
   with an empty `DEVELOPMENT_TEAM`, so you must select yours before it will sign.
3. Build and run.

No external dependencies — SwiftUI, AppKit and the system frameworks only.

The project uses Xcode's synchronized file groups, so files added or removed
under `HabitLedger/` are picked up automatically and the project file doesn't
need editing.

## License

HabitLedger is released under the MIT License. See [LICENSE](LICENSE).

---

© 2026 Nav Virdi — Liberated.Studio
