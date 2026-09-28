import Foundation

/// A note — `Notes/<title>.md` (FORMAT §4.2). Simple on purpose: title, tags, Markdown body with
/// `[[links]]` and `#tags` (SPEC: "the notes I got won't be that complex").
public struct Note: VaultItem, DocumentBacked {
    public static let kind = ItemKind.note
    public internal(set) var document: MarkdownDocument

    public init?(document: MarkdownDocument) {
        guard Self.validates(document) else { return nil }
        self.document = document
    }

    public static func new(
        title: String,
        id: ULID = ULID(),
        created: Timestamp = .now(),
        tags: [String] = [],
        body: String = ""
    ) -> Note {
        var fm = NewFrontMatter()
        fm.add("id", id.description)
        fm.add("type", kind.rawValue)
        fm.add("title", title, as: .text)
        fm.add("created", created.description)
        fm.add("updated", created.description)
        fm.add("tags", list: tags)
        return Note(document: MarkdownDocument(frontMatter: fm.frontMatter, body: body))!
    }

    public var title: String {
        frontMatter.string("title") ?? ""
    }

    /// Front-matter tags only; see `allTags` for inline `#tags` too.
    public var tags: [String] {
        frontMatter.list("tags")
    }

    /// Front-matter tags then inline `#tags`, without duplicates (case-insensitive), in order.
    public var allTags: [String] {
        var seen = Set<String>()
        return (tags + MarkdownText.inlineTags(in: document.body)).filter { seen.insert($0.lowercased()).inserted }
    }

    public var body: String {
        document.body
    }

    public mutating func setTitle(_ title: String) {
        setOptional("title", title, as: .text)
    }

    public mutating func setTags(_ tags: [String]) {
        editFrontMatter { $0.set("tags", .list(tags)) }
    }

    public mutating func setBody(_ body: String) {
        document.body = body
    }
}
