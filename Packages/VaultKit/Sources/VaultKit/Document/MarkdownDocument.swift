import Foundation

/// A vault file as text: an optional front-matter block and a Markdown body (FORMAT §4, A07).
///
/// `MarkdownDocument(parsing: text).text == text` for every input — that is the round-trip guarantee
/// (§4.5). Models read and write through this type, so an untouched file is never rewritten and an
/// edited file changes only the lines that were edited.
public struct MarkdownDocument: Equatable, Sendable {
    /// A UTF-8 byte-order mark, if the file had one. Kept so it survives a save.
    var byteOrderMark: String
    public var frontMatter: FrontMatter?
    public var body: String

    public init(parsing text: String) {
        var rest = Substring(text)
        byteOrderMark = ""
        if rest.unicodeScalars.first == "\u{FEFF}" {
            byteOrderMark = "\u{FEFF}"
            rest = Substring(rest.unicodeScalars.dropFirst())
        }
        let lines = Line.split(String(rest))
        if let first = lines.first, first.content == "---", !first.ending.isEmpty,
           let close = lines.dropFirst().firstIndex(where: { $0.content == "---" || $0.content == "..." })
        {
            frontMatter = FrontMatter(opening: first, lines: Array(lines[1 ..< close]), closing: lines[close])
            body = lines[(close + 1)...].map(\.raw).joined()
        } else {
            frontMatter = nil
            body = String(rest)
        }
    }

    /// A new document; `frontMatter` is filled in by the caller key by key, in format order.
    public init(frontMatter: FrontMatter?, body: String) {
        byteOrderMark = ""
        self.frontMatter = frontMatter
        self.body = body
    }

    public var text: String {
        byteOrderMark + (frontMatter?.text ?? "") + body
    }

    /// Reads bytes as UTF-8. Returns nil for anything that is not valid UTF-8: such a file is left alone,
    /// because decoding it lossily and saving would change bytes the app does not understand.
    public init?(data: Data) {
        // Not `String(data:encoding:)`: Foundation may drop a leading byte-order mark.
        guard let text = String(validating: data, as: UTF8.self) else { return nil }
        self.init(parsing: text)
    }

    public var data: Data {
        Data(text.utf8)
    }

    /// The front matter's `type:` — `note`, `task`, `habit`, `habit-week`, `habit-categories`.
    public var type: String? {
        frontMatter?.string("type")
    }
}
