import Foundation

/// The `type:` of a vault file (FORMAT §4).
public enum ItemKind: String, Sendable, Codable, CaseIterable {
    case note
    case task
    case habit
    case habitWeek = "habit-week"
    case habitCategories = "habit-categories"
}

/// A note, task, habit or habit week: a Markdown file with an `id` that never changes (FORMAT §4.1).
///
/// Every model is a *view* over its `MarkdownDocument` (A07). Reading goes through the front matter;
/// every setter edits only the lines it has to, so saving an item never rewrites what it didn't change.
public protocol VaultItem: Sendable, Equatable {
    static var kind: ItemKind { get }
    /// The file's text, including every edit made through the model.
    var document: MarkdownDocument { get }
    /// The document as it was read from disk; nil for an item made with `new` and not yet saved.
    /// A save refuses to overwrite a file that no longer matches it (someone else edited it).
    var loadedDocument: MarkdownDocument? { get }
    /// Nil unless the document has the right `type:` and a valid ULID `id:`.
    init?(document: MarkdownDocument)
    var title: String { get }
}

/// Internal write access for the models' shared helpers.
protocol DocumentBacked {
    var document: MarkdownDocument { get set }
    var loadedDocument: MarkdownDocument? { get set }
}

extension VaultItem where Self: DocumentBacked {
    /// A new item that exists only in memory until the Vault saves it.
    init(unsaved document: MarkdownDocument) {
        self.init(document: document)!
        loadedDocument = nil
    }
}

extension VaultItem {
    public var frontMatter: FrontMatter {
        document.frontMatter ?? FrontMatter()
    }

    /// Guaranteed valid: `init?(document:)` refuses documents without one.
    public var id: ULID {
        ULID(frontMatter.string("id") ?? "") ?? ULID(high: 0, low: 0)
    }

    public var created: Timestamp? {
        frontMatter.string("created").flatMap { Timestamp($0) }
    }

    public var updated: Timestamp? {
        frontMatter.string("updated").flatMap { Timestamp($0) }
    }

    /// `[[links]]` in the body.
    public var bodyLinks: [WikiLink] {
        WikiLink.all(in: document.body)
    }

    static func validates(_ document: MarkdownDocument) -> Bool {
        document.type == kind.rawValue && document.frontMatter?.string("id").flatMap { ULID($0) } != nil
    }
}

extension DocumentBacked {
    mutating func editFrontMatter(_ edit: (inout FrontMatter) -> Void) {
        var frontMatter = document.frontMatter ?? FrontMatter()
        edit(&frontMatter)
        document.frontMatter = frontMatter
    }

    /// Sets a key; a nil value empties an existing key and never adds a new empty one.
    mutating func setOptional(_ key: String, _ value: String?, as style: YAMLScalarStyle) {
        editFrontMatter { frontMatter in
            if let value {
                frontMatter.set(key, .scalar(value), as: style)
            } else if frontMatter.contains(key) {
                frontMatter.set(key, .null)
            }
        }
    }

    /// Marks the item as changed now. The Vault calls this when it saves an edited item.
    mutating func touch(at time: Timestamp) {
        setOptional("updated", time.description, as: .literal)
    }

    /// Edits the body as lines. `edit` also gets the line ending to use for new lines — the body's
    /// own, else the front matter's.
    mutating func editBody(_ edit: (inout [Line], String) -> Void) {
        var lines = Line.split(document.body)
        let ending = lines.first(where: { !$0.ending.isEmpty })?.ending ?? document.frontMatter?.lineEnding ?? "\n"
        edit(&lines, ending)
        document.body = lines.map(\.raw).joined()
    }
}

/// Builds the front matter of a new file, key by key, in FORMAT order.
struct NewFrontMatter {
    private(set) var frontMatter = FrontMatter()

    mutating func add(_ key: String, _ value: String?, as style: YAMLScalarStyle = .literal) {
        guard let value else { return }
        frontMatter.set(key, .scalar(value), as: style)
    }

    mutating func add(_ key: String, list: [String]) {
        guard !list.isEmpty else { return }
        frontMatter.set(key, .list(list))
    }

    mutating func add(_ key: String, map: [YAMLPair], as style: YAMLScalarStyle) {
        frontMatter.set(key, map.isEmpty ? .null : .map(map), as: style)
    }
}

/// Section helpers for bodies: `## Subtasks`, `## Log`.
enum MarkdownSection {
    /// `## Title` → (level 2, "Title"); nil for anything that isn't an ATX heading.
    static func heading(_ line: Line) -> (level: Int, title: String)? {
        let trimmed = line.content.drop { $0 == " " }
        let hashes = trimmed.prefix { $0 == "#" }
        guard (1 ... 6).contains(hashes.count) else { return nil }
        let rest = trimmed.dropFirst(hashes.count)
        guard rest.isEmpty || rest.first == " " || rest.first == "\t" else { return nil }
        return (hashes.count, rest.trimmingCharacters(in: .whitespaces))
    }

    /// Line indices of the section headed `title` (case-insensitive), excluding the heading line:
    /// up to the next heading of the same or a higher level.
    static func range(titled title: String, in lines: [Line]) -> (heading: Int, body: Range<Int>)? {
        guard let start = lines.firstIndex(where: { heading($0).map { $0.title.lowercased() == title.lowercased() } ?? false }),
              let level = heading(lines[start])?.level
        else { return nil }
        let end = lines[(start + 1)...].firstIndex { heading($0).map { $0.level <= level } ?? false } ?? lines.count
        return (start, (start + 1) ..< end)
    }

    /// Appends `newLines` as a new section at the end of the body, separated by a blank line.
    static func append(_ newLines: [Line], to lines: inout [Line], ending: String) {
        if let last = lines.last, last.ending.isEmpty {
            lines[lines.count - 1].ending = ending
        }
        if let last = lines.last, !last.isBlank {
            lines.append(Line(content: "", ending: ending))
        }
        lines += newLines
    }
}
