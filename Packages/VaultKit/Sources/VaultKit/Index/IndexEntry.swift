import Foundation

/// What the index knows about one Markdown file — enough for the Horizon, links and search without
/// re-reading the file. Codable so it can be cached in `.persona/index.json` (A06).
public struct IndexEntry: Codable, Equatable, Sendable {
    /// Vault-relative path with `/` separators, e.g. `Tasks/Send invoice.md`.
    public let path: String
    /// Nil for Markdown the app does not manage (no front matter, unknown `type:` or no valid `id`).
    public let kind: ItemKind?
    public let id: ULID?
    /// The `title:`, else the file name without `.md`.
    public let title: String
    public let tags: [String]
    /// Link targets, in file order: front-matter links, then body links, plan/log habits for weeks.
    public let links: [String]
    public let parent: String?
    /// Days the item sits on in the Horizon.
    public let days: [Day]
    /// Task status or habit category, for display without loading the file.
    public let status: String?
    public let category: String?
    /// Habit-week log rows.
    public let log: [LogRow]
    /// File modification date and size when the entry was made — the cache is reused only if both match.
    public let modified: Date?
    public let size: Int?

    public struct LogRow: Codable, Equatable, Sendable {
        public let day: Day
        public let habit: String
        public let minutes: Int
    }

    public var titleKey: String {
        MarkdownText.titleKey(title)
    }

    /// Builds the entry for a file's text. `path` decides the fallback title.
    public init(path: String, document: MarkdownDocument, modified: Date? = nil, size: Int? = nil) {
        self.path = path
        self.modified = modified
        self.size = size
        let fileTitle = Self.fileTitle(path)
        var parent: String?
        var status: String?
        var category: String?
        var days: [Day] = []
        var log: [LogRow] = []
        var tags: [String] = []
        var frontMatterLinks: [String] = []

        if let task = TaskItem(document: document) {
            kind = .task
            id = task.id
            title = task.title.isEmpty ? fileTitle : task.title
            tags = task.tags + MarkdownText.inlineTags(in: document.body)
            frontMatterLinks = task.links.map(\.target)
            parent = task.parent?.target
            status = task.status.rawValue
            days = task.horizonDay.map { [$0] } ?? []
        } else if let note = Note(document: document) {
            kind = .note
            id = note.id
            title = note.title.isEmpty ? fileTitle : note.title
            tags = note.allTags
            frontMatterLinks = note.bodyLinks.map(\.target)
            days = note.created.map { [$0.day] } ?? []
        } else if let habit = Habit(document: document) {
            kind = .habit
            id = habit.id
            title = habit.title.isEmpty ? fileTitle : habit.title
            tags = MarkdownText.inlineTags(in: document.body)
            frontMatterLinks = habit.bodyLinks.map(\.target)
            category = habit.category?.rawValue
        } else if let week = HabitWeek(document: document) {
            kind = .habitWeek
            id = week.id
            title = week.title
            log = week.log.map { LogRow(day: $0.day, habit: $0.habitLink?.target ?? $0.habit, minutes: $0.minutes) }
            frontMatterLinks = HabitCategory.allCases.compactMap { week.plan[$0]?.target } + log.map(\.habit) + week.bodyLinks.map(\.target)
            days = Array(Set(log.map(\.day))).sorted()
        } else if HabitCategories(document: document) != nil {
            kind = .habitCategories
            id = nil
            title = fileTitle
        } else {
            kind = nil
            id = nil
            title = document.frontMatter?.string("title") ?? fileTitle
            tags = (document.frontMatter?.list("tags") ?? []) + MarkdownText.inlineTags(in: document.body)
            frontMatterLinks = WikiLink.all(in: document.body).map(\.target)
        }

        var seenTags = Set<String>()
        self.tags = tags.filter { seenTags.insert($0.lowercased()).inserted }
        var seenLinks = Set<String>()
        links = frontMatterLinks.filter { seenLinks.insert(MarkdownText.titleKey($0)).inserted }
        self.parent = parent
        self.status = status
        self.category = category
        self.days = days
        self.log = log
    }

    /// `Tasks/Send invoice.md` → `Send invoice`.
    static func fileTitle(_ path: String) -> String {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return name.hasSuffix(".md") ? String(name.dropLast(3)) : name
    }
}
