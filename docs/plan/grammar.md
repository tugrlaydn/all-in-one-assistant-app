# Quick Input grammar v1 (§5)

One parser in VaultKit, used by the floating panel, by ⌘K, and by the notification text field.

Input is one line. The first token selects the kind; the rest is the title, with tokens allowed anywhere in the line.

| Prefix | Creates | Example |
|---|---|---|
| `t ` (or no prefix) | Task | `t Send invoice @fri !1 #work ~45m` |
| `n ` | Note | `n Antenna idea: try a helical element` |
| `h ` | Habit log entry | `h swim 45 evening` → habit by fuzzy title, minutes, optional note |
| `/` | Command | `/today` · `/week` · `/open <title>` · `/plan physical swim` |

| Token | Meaning |
|---|---|
| `@today` `@tom` `@fri` `@2026-10-03` `@+3d` | `scheduled` (tasks) / entry date (habit logs) |
| `@due:fri` | `due` |
| `#tag` | tag |
| `!1` `!2` `!3` | priority |
| `~45m` `~2h` | estimate |
| `>Parent title` | parent task (fuzzy match) |
| `[[Title]]` | link (kept in the body) |

The panel shows parsed fields as chips while you type. **Enter** saves and closes; **⌘Enter** saves and opens the item; **Esc** cancels. The default kind when no prefix is given is a setting (default: task). Unknown tokens stay in the title — the parser never eats text it doesn't understand.

Details (ratified 2026-09-29 with A16):
- Tokens apply only to the kinds that use them: in a note, `!1`, `~45m`, `>Parent` and `@date` stay text; in a habit log, `#tag` stays in its note.
- `@mon`…`@sun` mean the next such day, today included (`@fri` on a Friday is today); `@+Nd` goes up to about 100 years.
- The first date, due date, priority, estimate or parent wins; a repeat stays in the title.
- `>Parent title` runs until the next token or the end of the line.
- `[[links]]` are recorded and also stay in the text.
- A habit log splits at its first number: `h swim 45 evening` → habit `swim`, 45 minutes, note `evening`.

Why this grammar: `docs/decisions/A16-quick-input-grammar.md`.
