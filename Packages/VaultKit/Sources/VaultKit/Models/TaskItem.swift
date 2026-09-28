import Foundation

public enum TaskStatus: String, Sendable, CaseIterable {
    case todo, doing, done, dropped
}

/// A task — `Tasks/<title>.md` (FORMAT §4.3). Subtasks are checklist lines under `## Subtasks`,
/// nested by indentation, any depth; the file keeps whatever depth it has.
public struct TaskItem: VaultItem, DocumentBacked {
    public static let kind = ItemKind.task
    public internal(set) var document: MarkdownDocument
    public internal(set) var loadedDocument: MarkdownDocument?

    public init?(document: MarkdownDocument) {
        guard Self.validates(document) else { return nil }
        self.document = document
        loadedDocument = document
    }

    public static func new(
        title: String,
        id: ULID = ULID(),
        created: Timestamp = .now(),
        scheduled: Day? = nil,
        due: Day? = nil,
        priority: Int? = nil,
        estimate: Estimate? = nil,
        tags: [String] = [],
        parent: WikiLink? = nil,
        body: String = ""
    ) -> TaskItem {
        var fm = NewFrontMatter()
        fm.add("id", id.description)
        fm.add("type", kind.rawValue)
        fm.add("title", title, as: .text)
        fm.add("status", TaskStatus.todo.rawValue)
        fm.add("created", created.description)
        fm.add("updated", created.description)
        fm.add("scheduled", scheduled?.description)
        fm.add("due", due?.description)
        fm.add("priority", priority.map(String.init))
        fm.add("estimate", estimate?.description)
        fm.add("tags", list: tags)
        fm.add("parent", parent?.description, as: .text)
        return TaskItem(unsaved: MarkdownDocument(frontMatter: fm.frontMatter, body: body))
    }

    // MARK: Fields

    public var title: String { frontMatter.string("title") ?? "" }
    /// An unknown status word reads as `todo`; the file keeps it until the status is changed.
    public var status: TaskStatus { frontMatter.string("status").flatMap(TaskStatus.init) ?? .todo }
    public var scheduled: Day? { frontMatter.string("scheduled").flatMap { Day($0) } }
    public var due: Day? { frontMatter.string("due").flatMap { Day($0) } }
    public var doneAt: Timestamp? { frontMatter.string("done_at").flatMap { Timestamp($0) } }
    public var priority: Int? { frontMatter.int("priority").flatMap { (1 ... 3).contains($0) ? $0 : nil } }
    public var estimate: Estimate? { frontMatter.string("estimate").flatMap { Estimate($0) } }
    public var tags: [String] { frontMatter.list("tags") }
    public var parent: WikiLink? { frontMatter.string("parent").flatMap { WikiLink(parsing: $0) } }

    /// `links:` from the front matter, then `[[links]]` in the body (both count, FORMAT §4.3).
    public var links: [WikiLink] {
        frontMatter.list("links").compactMap { WikiLink(parsing: $0) } + bodyLinks
    }

    /// The day the task sits on in the Horizon: `scheduled`, else `due` (P2).
    public var horizonDay: Day? { scheduled ?? due }

    public mutating func setTitle(_ title: String) { setOptional("title", title, as: .text) }
    public mutating func setScheduled(_ day: Day?) { setOptional("scheduled", day?.description, as: .literal) }
    public mutating func setDue(_ day: Day?) { setOptional("due", day?.description, as: .literal) }
    public mutating func setEstimate(_ estimate: Estimate?) { setOptional("estimate", estimate?.description, as: .literal) }
    public mutating func setParent(_ parent: WikiLink?) { setOptional("parent", parent?.description, as: .text) }
    public mutating func setTags(_ tags: [String]) { editFrontMatter { $0.set("tags", .list(tags)) } }

    public mutating func setPriority(_ priority: Int?) {
        precondition(priority.map { (1 ... 3).contains($0) } ?? true, "priority is 1, 2 or 3")
        setOptional("priority", priority.map(String.init), as: .literal)
    }

    /// Sets the status; becoming `done` stamps `done_at`, leaving it clears `done_at`.
    public mutating func setStatus(_ status: TaskStatus, at time: Timestamp = .now()) {
        let wasDone = self.status == .done
        setOptional("status", status.rawValue, as: .literal)
        if status == .done, !wasDone {
            setOptional("done_at", time.description, as: .literal)
        } else if status != .done, wasDone {
            setOptional("done_at", nil, as: .literal)
        }
    }

    // MARK: Subtasks

    static let subtasksHeading = "Subtasks"

    /// The subtask tree, in file order.
    public var subtasks: [Subtask] {
        Subtask.tree(Self.checklist(in: Line.split(document.body)))
    }

    /// Done leaves ÷ all leaves (FORMAT §4.3); nil without subtasks.
    public var progress: Double? {
        let leaves = subtasks.flatMap(\.leaves)
        guard !leaves.isEmpty else { return nil }
        return Double(leaves.filter(\.isDone).count) / Double(leaves.count)
    }

    /// Ticks or unticks the subtask on body line `line` — one character in one line changes.
    public mutating func setSubtask(line: Int, done: Bool) {
        editBody { lines, _ in
            guard lines.indices.contains(line), var item = ChecklistLine(lines[line]) else { return }
            item.isDone = done
            lines[line].content = item.content
        }
    }

    /// Adds `- [ ] text` as the last child of the subtask on line `parent`, or as the last top-level
    /// subtask. Creates the `## Subtasks` section if the task has none. Returns the new line index.
    @discardableResult
    public mutating func addSubtask(_ text: String, under parent: Int? = nil) -> Int {
        let text = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        var inserted = 0
        editBody { lines, ending in
            guard let section = MarkdownSection.range(titled: Self.subtasksHeading, in: lines) else {
                MarkdownSection.append(
                    [Line(content: "## " + Self.subtasksHeading, ending: ending), Line(content: "- [ ] " + text, ending: ending)],
                    to: &lines, ending: ending
                )
                inserted = lines.count - 1
                return
            }
            let items = Self.checklist(in: lines)
            let newLine: ChecklistLine
            var insertAt: Int
            if let parent, let parentItem = items.first(where: { $0.line == parent }) {
                let descendants = items.drop { $0.line <= parent }.prefix { $0.item.width > parentItem.item.width }
                let childIndent = descendants.first?.item.indent ?? parentItem.item.indent + "  "
                newLine = ChecklistLine(indent: childIndent, bullet: parentItem.item.bullet, text: text)
                insertAt = (descendants.last?.line ?? parent) + 1
            } else {
                let topLevel = items.first
                newLine = ChecklistLine(indent: topLevel?.item.indent ?? "", bullet: topLevel?.item.bullet ?? "-", text: text)
                insertAt = (items.last?.line ?? section.heading) + 1
            }
            if insertAt == lines.count, let last = lines.last, last.ending.isEmpty {
                lines[lines.count - 1].ending = ending
            }
            lines.insert(Line(content: newLine.content, ending: ending), at: insertAt)
            inserted = insertAt
        }
        return inserted
    }

    /// Checklist lines inside the `## Subtasks` section, with their body line index.
    static func checklist(in lines: [Line]) -> [(line: Int, item: ChecklistLine)] {
        guard let section = MarkdownSection.range(titled: subtasksHeading, in: lines) else { return [] }
        return section.body.compactMap { index in ChecklistLine(lines[index]).map { (index, $0) } }
    }
}

/// One subtask and its children. `line` identifies it until the body is next edited.
public struct Subtask: Hashable, Sendable {
    public let line: Int
    public let text: String
    public let isDone: Bool
    public let depth: Int
    public internal(set) var children: [Subtask]

    public var leaves: [Subtask] {
        children.isEmpty ? [self] : children.flatMap(\.leaves)
    }

    /// Nests by indentation width: an item is a child of the nearest earlier item indented less.
    static func tree(_ flat: [(line: Int, item: ChecklistLine)]) -> [Subtask] {
        var roots: [Subtask] = []
        var path: [(width: Int, indexPath: [Int])] = []
        for (line, item) in flat {
            while let last = path.last, last.width >= item.width { path.removeLast() }
            let node = Subtask(line: line, text: item.text, isDone: item.isDone, depth: path.count, children: [])
            if let parent = path.last {
                let childIndex = insert(node, at: parent.indexPath, into: &roots)
                path.append((item.width, parent.indexPath + [childIndex]))
            } else {
                roots.append(node)
                path.append((item.width, [roots.count - 1]))
            }
        }
        return roots
    }

    private static func insert(_ node: Subtask, at indexPath: [Int], into nodes: inout [Subtask]) -> Int {
        let head = indexPath[0]
        if indexPath.count == 1 {
            nodes[head].children.append(node)
            return nodes[head].children.count - 1
        }
        return insert(node, at: Array(indexPath.dropFirst()), into: &nodes[head].children)
    }
}

/// `  - [x] text` split into parts, so ticking rewrites one character.
struct ChecklistLine {
    var indent: String
    var bullet: Character
    var mark: Character
    /// `" "` between `]` and the text, or `""` for a bare `- [ ]`.
    var separator: String
    var text: String

    var isDone: Bool {
        get { mark == "x" || mark == "X" }
        set { if newValue != isDone { mark = newValue ? "x" : " " } }
    }

    /// Indentation width, a tab counting as four spaces.
    var width: Int {
        indent.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
    }

    var content: String {
        indent + String(bullet) + " [" + String(mark) + "]" + separator + text
    }

    init(indent: String, bullet: Character, text: String) {
        self.indent = indent
        self.bullet = bullet
        mark = " "
        separator = text.isEmpty ? "" : " "
        self.text = text
    }

    init?(_ line: Line) {
        let content = line.content
        let indent = content.prefix { $0 == " " || $0 == "\t" }
        let rest = Array(content.dropFirst(indent.count))
        guard rest.count >= 5, "-*+".contains(rest[0]), rest[1] == " ", rest[2] == "[", rest[4] == "]",
              rest[3] == " " || rest[3] == "x" || rest[3] == "X",
              rest.count == 5 || rest[5] == " "
        else { return nil }
        self.indent = String(indent)
        bullet = rest[0]
        mark = rest[3]
        separator = rest.count > 5 ? " " : ""
        text = rest.count > 6 ? String(rest[6...]) : ""
    }
}
