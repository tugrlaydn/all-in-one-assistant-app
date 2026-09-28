import Foundation

/// An Obsidian-style link: `[[Title]]`, `[[Title#Heading]]`, `[[Title|shown text]]` (FORMAT §4.2).
/// Links resolve by title, case-insensitively, falling back to id (A15).
public struct WikiLink: Hashable, Sendable, CustomStringConvertible {
    public let target: String
    public let heading: String?
    public let alias: String?

    public init(_ target: String, heading: String? = nil, alias: String? = nil) {
        self.target = target.trimmingCharacters(in: .whitespaces)
        self.heading = heading
        self.alias = alias
    }

    /// Exactly one link and nothing else: `"[[Q4 invoicing]]"`.
    public init?(parsing text: some StringProtocol) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("[["), trimmed.hasSuffix("]]"), trimmed.count > 4 else { return nil }
        let inner = trimmed.dropFirst(2).dropLast(2)
        guard !inner.contains("[["), !inner.contains("]]") else { return nil }
        self.init(inner: inner)
    }

    init?(inner: Substring) {
        var rest = inner
        var alias: String?
        if let bar = rest.firstIndex(of: "|") {
            alias = String(rest[rest.index(after: bar)...])
            rest = rest[..<bar]
        }
        var heading: String?
        if let hash = rest.firstIndex(of: "#") {
            heading = String(rest[rest.index(after: hash)...])
            rest = rest[..<hash]
        }
        let target = rest.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return nil }
        self.init(target, heading: heading, alias: alias)
    }

    /// Every link in Markdown prose, in order. Embeds (`![[image.png]]`) and code are skipped.
    public static func all(in markdown: String) -> [WikiLink] {
        var links: [WikiLink] = []
        for line in MarkdownText.proseLines(markdown) {
            var search = line[...]
            while let open = search.range(of: "[[") {
                guard let close = search[open.upperBound...].range(of: "]]") else { break }
                let isEmbed = open.lowerBound > search.startIndex && search[search.index(before: open.lowerBound)] == "!"
                if !isEmbed, let link = WikiLink(inner: search[open.upperBound ..< close.lowerBound]) {
                    links.append(link)
                }
                search = search[close.upperBound...]
            }
        }
        return links
    }

    /// The key titles are matched by: case-folded, whitespace-trimmed.
    public var key: String {
        MarkdownText.titleKey(target)
    }

    public var description: String {
        "[[" + target + (heading.map { "#" + $0 } ?? "") + (alias.map { "|" + $0 } ?? "") + "]]"
    }
}

/// A time estimate, `45m`, `2h`, `1h30m` (FORMAT §4.3, grammar `~45m`).
public struct Estimate: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let minutes: Int

    public init?(minutes: Int) {
        guard minutes > 0 else { return nil }
        self.minutes = minutes
    }

    public init?(_ text: some StringProtocol) {
        let lower = text.lowercased().replacingOccurrences(of: " ", with: "")
        if let plain = Int(lower) {
            self.init(minutes: plain)
            return
        }
        var total = 0
        var number = ""
        var sawUnit = false
        for char in lower {
            if char.isASCII, char.isNumber {
                number.append(char)
            } else if char == "h" || char == "m", let value = Int(number) {
                total += char == "h" ? value * 60 : value
                number = ""
                sawUnit = true
            } else {
                return nil
            }
        }
        guard number.isEmpty, sawUnit else { return nil }
        self.init(minutes: total)
    }

    public var description: String {
        switch (minutes / 60, minutes % 60) {
        case (0, let m): "\(m)m"
        case (let h, 0): "\(h)h"
        case let (h, m): "\(h)h\(m)m"
        }
    }

    public static func < (lhs: Estimate, rhs: Estimate) -> Bool {
        lhs.minutes < rhs.minutes
    }
}

/// Helpers for reading Markdown prose without a full CommonMark parser (A07).
enum MarkdownText {
    /// Body lines outside fenced code blocks, with inline code spans blanked out.
    static func proseLines(_ markdown: String) -> [String] {
        var result: [String] = []
        var fence: String?
        for line in Line.split(markdown) {
            let trimmed = line.content.trimmingCharacters(in: .whitespaces)
            if let open = fence {
                if trimmed.hasPrefix(open) { fence = nil }
                continue
            }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                fence = String(trimmed.prefix(3))
                continue
            }
            result.append(withoutInlineCode(line.content))
        }
        return result
    }

    static func withoutInlineCode(_ text: String) -> String {
        guard text.contains("`") else { return text }
        var result = ""
        var inCode = false
        for char in text {
            if char == "`" {
                inCode.toggle()
                result.append(" ")
            } else {
                result.append(inCode ? " " : char)
            }
        }
        return result
    }

    /// Inline `#tags` in prose (Obsidian rules: letters, digits, `_`, `-`, `/`; not only digits).
    /// Headings (`# Title`) are not tags because a tag has no space after `#`.
    static func inlineTags(in markdown: String) -> [String] {
        var tags: [String] = []
        for line in proseLines(markdown) {
            let chars = Array(line)
            var index = 0
            while index < chars.count {
                defer { index += 1 }
                guard chars[index] == "#" else { continue }
                if index > 0 {
                    let before = chars[index - 1]
                    guard before.isWhitespace || before == "(" || before == "," else { continue }
                }
                var end = index + 1
                while end < chars.count, isTagCharacter(chars[end]) { end += 1 }
                let tag = String(chars[(index + 1) ..< end])
                if !tag.isEmpty, tag.contains(where: { !$0.isNumber }) {
                    tags.append(tag)
                }
                index = end - 1
            }
        }
        return tags
    }

    static func isTagCharacter(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || char == "_" || char == "-" || char == "/"
    }

    /// Titles and tags compare case-insensitively (Obsidian does the same).
    static func titleKey(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespaces).lowercased()
    }
}
