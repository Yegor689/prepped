# Prepped

**Checklists for getting ready before a dated event.**

Prepped is an iOS app for **checklists grouped under a due date**. Create a
list for anything with a deadline — a trip, an event, a move — add items, and
Prepped sends a local reminder as the date approaches while items are still
unfinished. Finished lists drop off the home screen but stay reachable under
**All Lists**.

## Features

- **Dated checklists** with a due date, accent color, notes, and items.
- **Home** shows only active lists, split into **Overdue** and **Upcoming**,
  each with a progress ring and relative due date.
- **Inline item editing** — tap the circle to check off, tap the text to edit,
  drag to reorder (unchecked items float above checked).
- **Per-list reminders** (none / 1 / 3 / 7 days before), delivered at 9:00 AM,
  only while items remain unfinished.
- **Completion flow** — a warning if you complete with open items, plus a
  celebration when you finish the last one.
- **All Lists** — active and completed, with the ability to reopen a list.
- **Light & dark app icon** and app-wide theming.

## Tech

SwiftUI + SwiftData, targeting iOS 27. Persistence is an explicit, on-disk
`ModelContainer`; additive schema changes migrate automatically and preserve
data (a store that can't open is backed up, not deleted).

See [PLAN.md](PLAN.md) for the full feature/status breakdown and
[MODEL.md](MODEL.md) for the data-layer reference.

## Build

Open `Untitled Project.xcodeproj` in Xcode, or from the command line:

```sh
xcodebuild -project "Untitled Project.xcodeproj" -scheme Prepped \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
