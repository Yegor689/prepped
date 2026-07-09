# Data Model — Prepped

This document describes the data layer of the Prepped app: the SwiftData
entities, their relationships, derived (computed) values, the persistence
container, and how the model drives notifications. It is the reference for
anyone changing storage, adding fields, or reasoning about persistence
behavior.

Source of truth: [MyApp/Models.swift](MyApp/Models.swift). Container setup lives
in [MyApp/ContentView.swift](MyApp/ContentView.swift); the color type in
[MyApp/ListColor.swift](MyApp/ListColor.swift).

---

## Overview

The domain has two entities in a parent/child relationship:

```
Checklist 1 ──< Item
   (a dated list)   (a to-do within that list)
```

- A **Checklist** is a named, dated container (e.g. "Weekend Trip") with an
  accent color and a completion flag.
- An **Item** is a single to-do belonging to exactly one checklist.

Both are SwiftData `@Model` classes, persisted to a local on-disk store. There
is no networking or sync layer.

---

## Entities

### `Checklist`

| Property        | Type        | Notes |
|-----------------|-------------|-------|
| `id`            | `UUID`      | Stable identity; also used as the notification request identifier. |
| `name`          | `String`    | User-facing title. |
| `notes`         | `String`    | Optional free text (defaults to `""`). |
| `dueDate`       | `Date`      | When the list is due; drives sorting, overdue state, and the reminder time. |
| `createdAt`     | `Date`      | Set to `.now` at init. |
| `isCompleted`   | `Bool`      | Manual "done" flag. `true` hides the list from Home; it remains in All Lists. |
| `colorName`     | `String`    | Raw value of a `ListColor` case; drives the accent. Defaults to `blue`. |
| `items`         | `[Item]`    | Cascade relationship to child items (see below). |

**Initializer**
```swift
init(name: String, notes: String = "", dueDate: Date,
     colorName: String = ListColor.blue.rawValue)
```
`id`, `createdAt`, `isCompleted` (`false`), and an empty `items` array are set
automatically.

#### Computed properties (not persisted)

| Property             | Returns  | Meaning |
|----------------------|----------|---------|
| `color`              | `ListColor` | `colorName` mapped back to the enum (falls back to `.blue` if unknown). |
| `totalItemCount`     | `Int`    | `items.count`. |
| `completedItemCount` | `Int`    | Count of items where `isDone`. |
| `allItemsDone`       | `Bool`   | `true` only when there is at least one item and all are done. |
| `progress`           | `Double` | `completed / total`, or `0` when empty. Range `0...1`. |
| `isOverdue`          | `Bool`   | `dueDate < now && !allItemsDone` — past due *and* still has open work. |
| `dueDescription`     | `String` | Day-granular relative phrase: "Due today", "Due tomorrow", "Due in N days", "1 day overdue", "N days overdue". Computed from calendar day boundaries, not raw time intervals. |

These are derived on read, so they always reflect current item state and the
current date without any stored duplication to keep in sync.

### `Item`

| Property     | Type          | Notes |
|--------------|---------------|-------|
| `id`         | `UUID`        | Stable identity. |
| `title`      | `String`      | The to-do text. |
| `isDone`     | `Bool`        | Checked/unchecked. Defaults to `false`. |
| `createdAt`  | `Date`        | Set to `.now` at init. |
| `order`      | `Int`         | Manual sort position within the parent (lower = higher up). |
| `checklist`  | `Checklist?`  | Inverse relationship to the owning list. |

**Initializer**
```swift
init(title: String, order: Int = 0, checklist: Checklist? = nil)
```

---

## Relationship

Declared on the parent:

```swift
@Relationship(deleteRule: .cascade, inverse: \Item.checklist)
var items: [Item]
```

- **Cascade delete**: deleting a `Checklist` deletes all its `Item`s. This is
  why deleting a list only requires deleting the parent; the items go with it.
- **Inverse**: `Item.checklist` is the back-reference SwiftData keeps in sync.

### Why `Item.checklist` is optional

The original design called for a **non-optional** back-reference so an item can
never be orphaned. In practice SwiftData's `@Relationship(inverse:)` macro
requires the inverse side to be optional to resolve the relationship graph, so
`checklist` is declared `Checklist?`.

The "no orphans" guarantee is instead enforced **in code**: items are only ever
created through a parent list (the detail view passes `checklist: checklist`
into the `Item` initializer and inserts it), and cascade delete removes them
with their parent. There is no code path that creates a free-floating item.

*Backlog:* if SwiftData later relaxes this, tighten `checklist` to non-optional.

---

## Ordering semantics

Items are grouped and sorted for display by the detail view, not by a stored
sort key alone:

- **Unchecked items float above checked items.** The detail view keeps two
  groups — `activeItems` (`!isDone`) and `doneItems` (`isDone`) — each sorted by
  `order` ascending.
- `order` is unique **within a group's rendering**, not globally. Reordering
  (`onMove`) renumbers the affected group from `0`. New items get
  `max(existing order) + 1` so they append to the end.

---

## Persistence & the container

Configured explicitly in the app entry point
([MyApp/ContentView.swift](MyApp/ContentView.swift)):

```swift
let schema = Schema([Checklist.self, Item.self])
let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
container = try ModelContainer(for: schema, configurations: [config])
```

Key points:

- **On-disk, not in-memory.** `isStoredInMemoryOnly: false` guarantees data
  persists across launches. (An earlier bug used the convenience
  `.modelContainer(for:)`, which *silently* fell back to an in-memory store when
  it couldn't open an incompatible on-disk store — data appeared to save within
  a session but vanished on relaunch. The explicit config prevents that class of
  failure.)

### Migration: additive changes preserve data

**Every stored property has a default value** (e.g. `var notes: String = ""`,
`var reminderLeadDays: Int = ReminderLead.oneDay.rawValue`). This is the key to
SwiftData's **automatic lightweight migration**: when a new property is added,
existing rows adopt its default and the store opens without loss. So the common
case — *adding a field* — **preserves existing data** and requires no migration
plan.

> ✅ **Rule of thumb:** adding a new stored property *with a default* is safe and
> non-destructive. Renaming, removing, retyping, or changing a relationship's
> cardinality is **not** additive and needs a real migration.

### Recovery: non-destructive fallback

If the store still can't be opened (a genuinely incompatible / non-additive
change), the init does **not** delete data. It **moves the store aside** to a
timestamped backup and starts fresh, logging a loud warning:

```swift
do {
    container = try ModelContainer(for: schema, configurations: [config])
    return
} catch {
    print("⚠️ SwiftData store could not be opened: \(error)")
    Self.backUpAndRemoveStore()   // moves default.store(+ -shm/-wal) → default.store.backup-<timestamp>
}
container = try ModelContainer(for: schema, configurations: [config])  // fresh store
```

The old store files are renamed, not removed, so a bad migration is recoverable
from `Application Support/default.store.backup-*` rather than gone.

> ⚠️ **History:** an earlier version *deleted* the store on any open failure,
> which wiped test data three times (`order`, `colorName`, `reminderLeadDays`).
> That behavior is gone. Data lost then is unrecoverable (it was deleted, not
> backed up).

> 📌 **Before shipping non-additive changes:** for renames/removals/retypes, add
> a versioned `SchemaMigrationPlan` with explicit migration stages. The current
> setup handles additive changes automatically but does not define custom
> migrations.

### Access pattern

Views read via SwiftData `@Query`:

- Home filters to active lists with a predicate and sorts by due date:
  ```swift
  @Query(filter: #Predicate<Checklist> { !$0.isCompleted },
         sort: \Checklist.dueDate) var activeChecklists: [Checklist]
  ```
- All Lists queries everything and partitions Active/Completed in memory.
- Writes go through the `@Environment(\.modelContext)` (`insert` / `delete`;
  mutating a model's properties autosaves).

---

## `ListColor`

A small closed enum ([MyApp/ListColor.swift](MyApp/ListColor.swift)) of eight
cases — `blue, teal, green, orange, pink, purple, indigo, gray` — each mapping
to a SwiftUI `Color`. Stored on `Checklist` as `colorName` (the raw string) so
the persisted value is stable and SwiftData-friendly; `Checklist.color` maps it
back, defaulting to `.blue` for any unrecognized value.

---

## How the model drives notifications

`NotificationManager` ([MyApp/NotificationManager.swift](MyApp/NotificationManager.swift))
derives everything it needs from the model — it stores nothing itself:

- **Fire time** = the due day minus `reminderLeadDays`, set to **9:00 AM**
  (constant `reminderHour`). The per-list `reminderLead` (`ReminderLead`:
  none / 1 / 3 / 7 days) chooses the offset. If that moment has already passed,
  it schedules shortly from now instead of skipping.
- **Whether to schedule** = only when `!isCompleted && !allItemsDone &&
  reminderLead != .none`.
- **Identity** = `checklist.id.uuidString` as the request identifier, so a
  reschedule replaces the prior request cleanly.

Because iOS can't evaluate app logic at fire time, the "only remind while
unfinished" rule is enforced by **cancelling/rescheduling on model changes**
(item toggle/add/delete, list create/edit, complete/reopen) and a full resync
on app foreground.

---

## Change checklist (when editing the model)

1. Edit [MyApp/Models.swift](MyApp/Models.swift); update this document.
2. **Give any new stored property a default value** (`= …`). This keeps the
   change additive so SwiftData migrates the store automatically and **existing
   data is preserved** — no reset. Skipping the default risks an open failure.
3. **Non-additive changes** (rename / remove / retype a property, change a
   relationship) are *not* auto-migratable — add a versioned
   `SchemaMigrationPlan` before making them, or existing stores will fall back to
   the (non-destructive) backup-and-recreate path and start empty.
4. If the change affects reminder timing or completion, verify
   `NotificationManager` still schedules/cancels correctly.
5. Keep computed properties as the single source for derived state — avoid
   storing values that can be computed from items or dates.
