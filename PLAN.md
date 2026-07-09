# Prepped — Project Plan & Status

*Prepped* — checklists for getting ready before a dated event.

## Overview
An iOS app for **checklists grouped under a dated event** (a "trip" like a
vacation was the original example, but the concept is generic). Each
**checklist** has a due date and a set of **items**; as the due date approaches
while items remain unfinished, the app sends a local notification. Completed
checklists are hidden from the home list but reachable via **All Lists**.

Built with **SwiftUI + SwiftData**, targeting the `Prepped` target
(iOS 18 deployment). See [MODEL.md](MODEL.md) for the data layer in detail.

---

## Status

### Done
- **Data layer** — `Checklist` + `Item` SwiftData models with an explicit,
  disk-backed `ModelContainer`. Additive schema changes **migrate and preserve
  data** (all stored props have defaults); if a store can't open it's **backed
  up, not deleted**. (See [MODEL.md](MODEL.md).)
- **Home (Lists)** — active lists only, split into **Overdue / Upcoming**
  sections. Each row: colored **progress ring**, relative due date, item count,
  a **note glyph** when notes exist, and a red accent + **"Overdue" pill** for
  overdue lists. Swipe-to-delete with a confirmation dialog.
- **All Lists** — Active / Completed sections; completed lists can be reopened.
- **Detail** — add items inline (field stays focused for rapid entry; pending
  text auto-commits on blur / leaving the screen); tap the circle to check off,
  **tap the item text to edit inline**; swipe to delete; drag-to-reorder
  (unchecked float above checked). Header card with % ring, due info, "N left",
  and reminder timing. **Mark Complete** capsule warns if items remain unfinished;
  finishing the last item fires a **completion celebration** overlay + haptic.
  Notes shown in a labeled "Notes" section.
- **Add / Edit form** — name, due date, **reminder lead-time picker**, notes, and
  an 8-swatch **color picker**.
- **Notifications** — `NotificationManager` schedules a reminder at the per-list
  lead time (none / 1 / 3 / 7 days before), delivered at **9:00 AM**, only while
  items remain unfinished; cancels / reschedules on every relevant change and
  resyncs on foreground.
- **Per-list color** — each list carries a `ListColor`, used as its accent
  across row, detail header, and buttons. App-wide indigo tint.
- **App name** — "Prepped" (display name set).
- **App icon** — progress-ring + checklist mark, with an explicit **dark-mode
  variant**, wired via `Assets.xcassets/AppIcon`.

### Not yet done / backlog
- **Non-optional `Item.checklist`** — currently optional (SwiftData
  `@Relationship(inverse:)` constraint); orphans are prevented in code.
- **Versioned migration plan** — additive changes are handled automatically, but
  non-additive changes (rename/remove/retype) would still fall back to the
  backup-and-recreate path. Add a `SchemaMigrationPlan` before making any.
- Possible extras: reminder **time-of-day** picker (currently fixed 9 AM),
  search on home, duplicate-as-template.

---

## Screens
1. **Lists (Home)** — `ContentView.swift` — active lists only, `+ Add`,
   `All Lists`.
2. **All Lists** — `AllListsView.swift` — Active/Completed, reopen.
3. **Detail** — `ChecklistDetailView.swift` — items, reorder, complete, edit.
4. **Add / Edit** — `ChecklistFormView.swift` — shared form with color picker.

Shared UI: `ProgressRing.swift`, `ListColor.swift`. Notifications:
`NotificationManager.swift`. Models + `ReminderLead`: `Models.swift`.

---

## Key decisions
- **Completion is manual** (button / prompt), never auto-hide, so
  "hidden when done" stays predictable. Marking complete with open items warns
  first.
- **Reminder lead time is per-list** (none / 1 / 3 / 7 days before), stored on
  the model, delivered at a fixed **9:00 AM**.
- **Persistence is explicit and disk-backed.** Additive schema changes migrate
  automatically (stored props have defaults); a store that can't open is moved
  to a timestamped backup rather than deleted. (See [MODEL.md](MODEL.md).)

---

## Verification
- Build: `xcodebuild -project "Prepped.xcodeproj" -scheme Prepped
  -destination 'platform=iOS Simulator,name=iPhone 17'`.
- Manual: create a list (pick a color) → add several items in a row → check them
  off → confirm the complete prompt → it leaves home and appears under
  Completed in All Lists → reopen. Type an item and back out without Enter →
  it still saves.
- Notifications: set a reminder lead time → a pending request exists (fires 9 AM
  that day); finish the items or set reminder to None → it's cancelled.
- Data safety: add a list, relaunch → it persists across launches and survives
  additive model changes.
