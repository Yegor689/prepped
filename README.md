<p align="center">
  <img src="assets/logo.png" alt="Prepped" width="160">
</p>

<h1 align="center">Prepped</h1>

<p align="center"><strong>Dated checklists that remind you before time runs out.</strong></p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS-lightgrey" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.0-orange" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="License">
</p>

Prepped turns anything with a deadline — a trip, an event, a move — into a
simple checklist with a due date. Add your items, pick a color, and Prepped
sends a native reminder as the date approaches while things are still
unfinished. It's a native SwiftUI app: quiet, quick, and built to get out of
your way. And because losing a list you were counting on is its own small
disaster, your data lives in an on-disk store that migrates safely across
updates — a store that can't open is backed up, never deleted.

## Why Prepped

- **A list, not a form.** Name it, give it a due date, and type your items —
  no ceremony.
- **Reminders that reach you.** Each list nudges you a day, three days, or a
  week ahead, and only while items are still unfinished.
- **Two ways to look at it.** A home split into **Overdue** and **Upcoming**, or
  an **All Lists** view of everything active and completed.
- **Done means done.** Finished lists leave home but stay one tap away, and
  reopen whenever you need them.
- **Yours to keep.** An on-disk store that migrates safely across updates —
  a store that can't open is backed up, never deleted.

## Requirements

- iOS 18 or later
- Xcode 26 or later

## Getting Started

```bash
git clone https://github.com/Yegor689/prepped.git
```

Open `Prepped.xcodeproj` in Xcode and run (⌘R). No dependencies, no setup —
pure SwiftUI and SwiftData.

## Architecture

The app is a SwiftUI `NavigationStack` over a SwiftData store. Two `@Model`
types — `Checklist` and its child `Item`s — back `@Query`-driven views, with
`NotificationManager` handling reminder scheduling as a side effect of model
changes. The container is explicit and disk-backed: additive migrations happen
automatically, and a store that can't open is backed up rather than deleted. See
[MODEL.md](MODEL.md) for the data model and [PLAN.md](PLAN.md) for the feature
breakdown.

## License

MIT
