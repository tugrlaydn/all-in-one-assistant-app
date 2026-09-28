import Foundation

/// One line of a file, kept with its exact terminator so joining lines gives back the same bytes.
struct Line: Equatable, Sendable {
    /// The line without its terminator.
    var content: String
    /// `"\n"`, `"\r\n"`, or `""` for a last line without a newline.
    var ending: String

    var raw: String { content + ending }

    /// Splits text into lines. Joining the `raw` of the result reproduces `text` exactly.
    ///
    /// Works on UTF-8 bytes: Swift treats `"\r\n"` as one `Character`, which would hide line ends.
    static func split(_ text: String) -> [Line] {
        var lines: [Line] = []
        let bytes = Array(text.utf8)
        var start = 0
        for index in bytes.indices where bytes[index] == 0x0A {
            let hasCR = index > start && bytes[index - 1] == 0x0D
            let contentEnd = hasCR ? index - 1 : index
            lines.append(Line(
                content: String(decoding: bytes[start ..< contentEnd], as: UTF8.self),
                ending: hasCR ? "\r\n" : "\n"
            ))
            start = index + 1
        }
        if start < bytes.count {
            lines.append(Line(content: String(decoding: bytes[start...], as: UTF8.self), ending: ""))
        }
        return lines
    }

    /// Leading spaces and tabs.
    var indentation: Substring {
        content.prefix { $0 == " " || $0 == "\t" }
    }

    var isBlank: Bool {
        content.allSatisfy { $0 == " " || $0 == "\t" }
    }
}
