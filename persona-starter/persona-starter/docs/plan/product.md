# Product — what we are building, and how it should look

Section numbers are kept from the master plan (see `docs/plan/README.md` for the map).

## 1. What we are building (plain language)

A personal macOS app that is a set of tools sharing one home: **notes**, **tasks**, and **habits**.

- Its home screen is a **horizontal calendar** — "the Horizon" — that runs across the whole window. The day you focus is a wide column; the other days shrink into narrow columns where you can *feel* how full they are without reading them. Notes, tasks, and habit entries sit on their days, and related items are drawn connected across the calendar.
- A **quick-input panel** opens anywhere on the Mac with a keyboard shortcut, like Spotlight or Alfred. You type one line — `t Send invoice @fri #work` or `h swim 45` — and it becomes a task, a note, or a habit entry. The same one-line language works inside the app (⌘K).
- **Habits** are organised in five fixed categories — Physical, Creative, Knowledge, Mindset, Monetizable. Each category has a weekly time budget; the actual hobby can change from week to week (swim this week, cycle next). The app watches your pace and nudges you with a notification that lets you log time *from the notification itself*, without opening the app.
- Everything is stored as ordinary **Markdown files** in a folder — the **Vault**. You can open them in Finder, Obsidian, or any editor; the app is a native, faster front end for them. The folder lives in iCloud Drive, so it follows you to every Apple device.
- The **Vault canvas** shows the whole vault — notes, tasks, habits — on a zoomable grid.

It should feel like Apple made it, and look unmistakably like *this* app.

---

---

## 6. Design language brief — "native, and unmistakably this app"

- **The substrate is native:** Liquid Glass materials, SF Symbols, the standard menu bar, Settings (⌘,), toolbar and inspector, system fonts, system selection and focus behaviour.
- **The identity comes from four things**, each defined once in `DesignKit` and nowhere else:
  1. **The Horizon motif** — the horizontal day ribbon with accordion focus. It is the signature of the app and reappears, small, in the quick-input panel and the menu-bar popover.
  2. **Colour** — one accent (D3) plus a fixed semantic set: note, task, and the five habit-category colours. Colour encodes *kind*, never decoration. Glass never sits on an element whose colour carries meaning.
  3. **Type** — SF Pro; one scale (`display`, `title`, `body`, `meta`); tabular numerals for dates and minutes.
  4. **Motion** — two springs (`quick` ≈ 0.25 s, `settle` ≈ 0.45 s) used for column focus, chip appearance, and panel show/hide. Nothing else animates. Reduce Motion → crossfades.
- **Keyboard map:** `⌥Space` quick input (D3) · `⌘K` in-app command bar · `⌘N` new note · `⌘T` new task · `⌘⇧H` log habit · `← / →` move the focused day · `⌘⇧T` jump to today · `⌘F` search · `⌘1…4` Horizon / Notes / Tasks / Habits · `⌘5` Vault canvas · `Space` complete the selected task.
- Every UI package ships with a screenshot in its report. The owner judges the look; the agent proposes, never assumes.

Design tooling (Figma / SwiftUI Motion Lab / Blender) is decision A14: `docs/decisions/A14-design-tooling.md`.
