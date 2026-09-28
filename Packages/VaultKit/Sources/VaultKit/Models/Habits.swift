import Foundation

/// The five fixed habit categories from SPEC.
public enum HabitCategory: String, Sendable, CaseIterable, Codable {
    case physical, creative, knowledge, mindset, monetizable
}

/// A habit — `Habits/<title>.md` (FORMAT §4.4): one hobby inside a category, e.g. Swimming → physical.
public struct Habit: VaultItem, DocumentBacked {
    public static let kind = ItemKind.habit
    public internal(set) var document: MarkdownDocument
    public internal(set) var loadedDocument: MarkdownDocument?

    public init?(document: MarkdownDocument) {
        guard Self.validates(document) else { return nil }
        self.document = document
        loadedDocument = document
    }

    public static func new(
        title: String,
        category: HabitCategory,
        defaultMinutes: Int? = nil,
        id: ULID = ULID(),
        created: Timestamp = .now()
    ) -> Habit {
        var fm = NewFrontMatter()
        fm.add("id", id.description)
        fm.add("type", kind.rawValue)
        fm.add("title", title, as: .text)
        fm.add("category", category.rawValue)
        fm.add("active", "true")
        fm.add("default_minutes", defaultMinutes.map(String.init))
        fm.add("created", created.description)
        return Habit(unsaved: MarkdownDocument(frontMatter: fm.frontMatter, body: ""))
    }

    public var title: String { frontMatter.string("title") ?? "" }
    public var category: HabitCategory? { frontMatter.string("category").flatMap(HabitCategory.init) }
    /// Missing means active.
    public var isActive: Bool { frontMatter.bool("active") ?? true }
    public var defaultMinutes: Int? { frontMatter.int("default_minutes") }

    public mutating func setTitle(_ title: String) { setOptional("title", title, as: .text) }
    public mutating func setCategory(_ category: HabitCategory) { setOptional("category", category.rawValue, as: .literal) }
    public mutating func setActive(_ active: Bool) { setOptional("active", String(active), as: .literal) }
    public mutating func setDefaultMinutes(_ minutes: Int?) { setOptional("default_minutes", minutes.map(String.init), as: .literal) }
}

/// `Habits/Categories.md` (FORMAT §4.4): weekly budgets and nudge times. No id — there is one per vault.
/// Budgets live in the vault, not in app settings, so they sync with everything else (A15).
public struct HabitCategories: Equatable, Sendable, DocumentBacked {
    public static let kind = ItemKind.habitCategories
    public static let fileName = "Categories.md"
    public internal(set) var document: MarkdownDocument
    public internal(set) var loadedDocument: MarkdownDocument?

    public init?(document: MarkdownDocument) {
        guard document.type == Self.kind.rawValue else { return nil }
        self.document = document
        loadedDocument = document
    }

    /// Created only when the owner first sets a budget — never as sample data (§8.6, D10).
    public static func new(budgets: [HabitCategory: Int], nudgeTimes: [TimeOfDay]) -> HabitCategories {
        var fm = NewFrontMatter()
        fm.add("type", kind.rawValue)
        fm.add(
            "budget_minutes_per_week",
            map: HabitCategory.allCases.compactMap { category in budgets[category].map { YAMLPair(category.rawValue, String($0)) } },
            as: .literal
        )
        fm.add("nudge_times", list: nudgeTimes.map(\.description))
        var categories = HabitCategories(document: MarkdownDocument(frontMatter: fm.frontMatter, body: ""))!
        categories.loadedDocument = nil
        return categories
    }

    private var frontMatter: FrontMatter { document.frontMatter ?? FrontMatter() }

    /// Minutes per week for each category that has a budget.
    public var budgets: [HabitCategory: Int] {
        var result: [HabitCategory: Int] = [:]
        for pair in frontMatter.map("budget_minutes_per_week") {
            if let category = HabitCategory(rawValue: pair.key), let minutes = pair.value.flatMap({ Int($0) }) {
                result[category] = minutes
            }
        }
        return result
    }

    public var nudgeTimes: [TimeOfDay] {
        frontMatter.list("nudge_times").compactMap { TimeOfDay($0) }.sorted()
    }

    /// Changes one category's line only.
    public mutating func setBudget(_ minutes: Int?, for category: HabitCategory) {
        editFrontMatter { $0.setMapValue("budget_minutes_per_week", category.rawValue, minutes.map(String.init), as: .literal) }
    }

    public mutating func setNudgeTimes(_ times: [TimeOfDay]) {
        editFrontMatter { $0.set("nudge_times", .list(times.sorted().map(\.description))) }
    }
}

/// `Habits/Weeks/2026-W40.md` (FORMAT §4.4): this week's hobby per category plus the time log.
public struct HabitWeek: VaultItem, DocumentBacked {
    public static let kind = ItemKind.habitWeek
    public internal(set) var document: MarkdownDocument

    static let logHeading = "Log"
    static let columns = ["date", "habit", "minutes", "note"]

    public internal(set) var loadedDocument: MarkdownDocument?

    public init?(document: MarkdownDocument) {
        guard Self.validates(document), document.frontMatter?.string("week").flatMap({ ISOWeek($0) }) != nil
        else { return nil }
        self.document = document
        loadedDocument = document
    }

    public static func new(week: ISOWeek, id: ULID = ULID()) -> HabitWeek {
        var fm = NewFrontMatter()
        fm.add("id", id.description)
        fm.add("type", kind.rawValue)
        fm.add("week", week.description)
        fm.add("plan", map: [], as: .text)
        let body = "## Log\n| date | habit | minutes | note |\n|---|---|---|---|\n"
        return HabitWeek(unsaved: MarkdownDocument(frontMatter: fm.frontMatter, body: body))
    }

    public var week: ISOWeek { frontMatter.string("week").flatMap { ISOWeek($0) }! }
    public var title: String { week.description }

    /// This week's hobby per category (each optional).
    public var plan: [HabitCategory: WikiLink] {
        var result: [HabitCategory: WikiLink] = [:]
        for pair in frontMatter.map("plan") {
            if let category = HabitCategory(rawValue: pair.key), let link = pair.value.flatMap({ WikiLink(parsing: $0) }) {
                result[category] = link
            }
        }
        return result
    }

    public mutating func setPlan(_ habit: WikiLink?, for category: HabitCategory) {
        editFrontMatter { $0.setMapValue("plan", category.rawValue, habit?.description) }
    }

    // MARK: Log

    /// Rows of the `## Log` table. Rows without a valid date or minutes are skipped (and kept in the file).
    public var log: [HabitLogEntry] {
        let lines = Line.split(document.body)
        guard let table = Self.logTable(in: lines) else { return [] }
        return table.rows.compactMap { index in
            let cells = HabitLogEntry.cells(lines[index].content)
            func cell(_ name: String) -> String? {
                table.columns.firstIndex(of: name).flatMap { cells.indices.contains($0) ? cells[$0] : nil }
            }
            guard let day = cell("date").flatMap({ Day($0) }), let minutes = cell("minutes").flatMap({ Int($0) }),
                  let habit = cell("habit")
            else { return nil }
            return HabitLogEntry(day: day, habit: habit, minutes: minutes, note: cell("note") ?? "", line: index)
        }
    }

    /// Appends a row after the last row of the log table, creating the section or table if needed.
    public mutating func appendLog(day: Day, habit: WikiLink, minutes: Int, note: String = "") {
        let row = HabitLogEntry.row([day.description, habit.description, String(minutes), note])
        editBody { lines, ending in
            let rowLine = Line(content: row, ending: ending)
            let header = [
                Line(content: HabitLogEntry.row(Self.columns), ending: ending),
                Line(content: "|---|---|---|---|", ending: ending),
            ]
            if let table = Self.logTable(in: lines) {
                let insertAt = (table.rows.last ?? table.separator) + 1
                if insertAt == lines.count, let last = lines.last, last.ending.isEmpty {
                    lines[lines.count - 1].ending = ending
                }
                lines.insert(rowLine, at: insertAt)
            } else if let section = MarkdownSection.range(titled: Self.logHeading, in: lines) {
                if section.heading == lines.count - 1, lines[section.heading].ending.isEmpty {
                    lines[section.heading].ending = ending
                }
                lines.insert(contentsOf: header + [rowLine], at: section.heading + 1)
            } else {
                MarkdownSection.append([Line(content: "## " + Self.logHeading, ending: ending)] + header + [rowLine], to: &lines, ending: ending)
            }
        }
    }

    /// The log table: its column names (lowercased), separator line and data-row line indices.
    static func logTable(in lines: [Line]) -> (columns: [String], separator: Int, rows: [Int])? {
        guard let section = MarkdownSection.range(titled: logHeading, in: lines) else { return nil }
        let tableLines = section.body.filter { lines[$0].content.trimmingCharacters(in: .whitespaces).hasPrefix("|") }
        guard tableLines.count >= 2 else { return nil }
        let separatorCells = HabitLogEntry.cells(lines[tableLines[1]].content)
        guard !separatorCells.isEmpty, separatorCells.allSatisfy({ $0.allSatisfy { "-: ".contains($0) } && $0.contains("-") })
        else { return nil }
        let columns = HabitLogEntry.cells(lines[tableLines[0]].content).map { $0.lowercased() }
        // Data rows: the contiguous run of table lines after the separator.
        var rows: [Int] = []
        var expected = tableLines[1] + 1
        for index in tableLines.dropFirst(2) where index == expected {
            rows.append(index)
            expected += 1
        }
        return (columns, tableLines[1], rows)
    }
}

/// One row of a week's log: `| 2026-09-28 | [[Swimming]] | 45 | evening |`.
public struct HabitLogEntry: Hashable, Sendable {
    public let day: Day
    /// The habit cell as written — normally a `[[link]]`.
    public let habit: String
    public let minutes: Int
    public let note: String
    /// Body line index of the row.
    public let line: Int

    public var habitLink: WikiLink? { WikiLink(parsing: habit) }

    /// Cells of a table row; `\|` is a literal pipe.
    static func cells(_ row: String) -> [String] {
        var cells: [String] = []
        var current = ""
        var escaped = false
        for char in row.trimmingCharacters(in: .whitespaces) {
            if escaped {
                current.append(char == "|" ? "|" : "\\" + String(char))
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "|" {
                cells.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        if escaped { current.append("\\") }
        cells.append(current)
        // A row starts and ends with `|`: drop the empty outer cells.
        if cells.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { cells.removeFirst() }
        if cells.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { cells.removeLast() }
        return cells.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    static func row(_ cells: [String]) -> String {
        "| " + cells.map {
            $0.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "|", with: "\\|")
        }.joined(separator: " | ") + " |"
    }
}
