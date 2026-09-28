import Foundation

/// How a scalar is written back to YAML.
public enum YAMLScalarStyle: Sendable {
    /// A string. Quoted whenever YAML would read it as something else (a number, a date, `true`, …)
    /// or when it contains characters YAML gives a meaning to.
    case text
    /// A number, boolean, date, timestamp or enum word: written as given, quoted only if unsafe.
    case literal
}

/// The small slice of YAML scalar syntax the vault format needs (FORMAT §4, A07): plain, single- and
/// double-quoted scalars, trailing comments, and flow collections of scalars.
enum YAMLScalar {
    /// Splits the text after `key:` into its value and the trailing whitespace + comment.
    /// `"todo   # a | b"` → (`"todo"`, `"   # a | b"`). Leading whitespace is returned separately.
    static func splitComment(_ text: Substring) -> (leading: Substring, value: Substring, trailing: Substring) {
        let leading = text.prefix { $0 == " " || $0 == "\t" }
        let rest = text[leading.endIndex...]
        var quote: Character?
        var previous: Character = " "
        var escaped = false
        var commentStart = rest.endIndex
        var index = rest.startIndex
        while index < rest.endIndex {
            let char = rest[index]
            if let open = quote {
                if escaped {
                    escaped = false
                } else if open == "\"", char == "\\" {
                    escaped = true
                } else if char == open {
                    quote = nil
                }
            } else if char == "\"" || char == "'", previous == " " || previous == "\t" || previous == "["
                || previous == "," || previous == "{" || index == rest.startIndex
            {
                quote = char
            } else if char == "#", previous == " " || previous == "\t" || index == rest.startIndex {
                commentStart = index
                break
            }
            previous = char
            index = rest.index(after: index)
        }
        let beforeComment = rest[rest.startIndex ..< commentStart]
        let value = beforeComment.reversed().drop { $0 == " " || $0 == "\t" }
        let valueEnd = rest.index(rest.startIndex, offsetBy: value.count)
        return (leading, rest[rest.startIndex ..< valueEnd], rest[valueEnd...])
    }

    /// The string a single scalar stands for: quotes removed and escapes resolved.
    static func unquote(_ text: Substring) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, let first = trimmed.first, first == trimmed.last else { return trimmed }
        let inner = trimmed.dropFirst().dropLast()
        if first == "'" {
            return inner.replacingOccurrences(of: "''", with: "'")
        }
        guard first == "\"" else { return trimmed }
        var result = ""
        var iterator = inner.makeIterator()
        while let char = iterator.next() {
            guard char == "\\", let next = iterator.next() else {
                result.append(char)
                continue
            }
            switch next {
            case "n": result.append("\n")
            case "t": result.append("\t")
            case "r": result.append("\r")
            case "0": result.append("\0")
            case "u":
                var hex = ""
                for _ in 0 ..< 4 {
                    if let digit = iterator.next() { hex.append(digit) }
                }
                if let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) {
                    result.unicodeScalars.append(scalar)
                } else {
                    result += "\\u" + hex
                }
            default: result.append(next)
            }
        }
        return result
    }

    /// Items of a flow collection body (without the outer brackets), split on top-level commas.
    static func splitFlow(_ inner: Substring) -> [Substring] {
        var items: [Substring] = []
        var depth = 0
        var quote: Character?
        var escaped = false
        var start = inner.startIndex
        var index = inner.startIndex
        while index < inner.endIndex {
            let char = inner[index]
            if let open = quote {
                if escaped { escaped = false }
                else if open == "\"", char == "\\" { escaped = true }
                else if char == open { quote = nil }
            } else {
                // A quote only opens a quoted item at the item's start: `it's` is plain text.
                let atItemStart = inner[start ..< index].allSatisfy { $0 == " " || $0 == "\t" }
                switch char {
                case "\"" where atItemStart, "'" where atItemStart: quote = char
                case "[", "{": depth += 1
                case "]", "}": depth -= 1
                case "," where depth == 0:
                    items.append(inner[start ..< index])
                    start = inner.index(after: index)
                default: break
                }
            }
            index = inner.index(after: index)
        }
        items.append(inner[start...])
        let trimmed = items.map { $0.trimmingCharacters(in: .whitespaces)[...] }
        // `[a, b,]` and `[]` leave an empty last item.
        if let last = trimmed.last, last.isEmpty { return Array(trimmed.dropLast()) }
        return trimmed
    }

    // MARK: Writing

    static func render(_ value: String, style: YAMLScalarStyle, inFlow: Bool = false) -> String {
        needsQuotes(value, style: style, inFlow: inFlow) ? doubleQuoted(value) : value
    }

    static func doubleQuoted(_ value: String) -> String {
        var result = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\t": result += "\\t"
            case "\r": result += "\\r"
            case _ where scalar.value < 0x20 || scalar.value == 0x7F:
                result += String(format: "\\u%04X", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }

    private static let indicatorStarts: Set<Character> = [
        "-", "?", ":", ",", "[", "]", "{", "}", "#", "&", "*", "!", "|", ">", "'", "\"", "%", "@", "`",
    ]
    private static let reservedWords: Set<String> = ["true", "false", "yes", "no", "on", "off", "null", "~", "y", "n"]

    static func needsQuotes(_ value: String, style: YAMLScalarStyle, inFlow: Bool) -> Bool {
        guard let first = value.first, let last = value.last else { return true }
        if first.isWhitespace || last.isWhitespace { return true }
        if indicatorStarts.contains(first) { return true }
        if value.contains(": ") || value.contains(" #") || last == ":" { return true }
        if value.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) { return true }
        if inFlow, value.contains(where: { ",[]{}".contains($0) }) { return true }
        if style == .text, looksLikeNonString(value) { return true }
        return false
    }

    /// Would a YAML reader (Obsidian, Hugo, …) read this plain text as something other than a string?
    static func looksLikeNonString(_ value: String) -> Bool {
        let lower = value.lowercased()
        if reservedWords.contains(lower) { return true }
        if [".inf", "-.inf", "+.inf", ".nan"].contains(lower) { return true }
        if Double(value) != nil || lower.hasPrefix("0x") || lower.hasPrefix("0o") { return true }
        // YAML 1.1 reads `20:00` as the base-60 number 1200.
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        if parts.count > 1, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }) {
            return true
        }
        // Dates and timestamps: 2026-09-28, 2026-09-28T09:12:00+03:00
        let digits = Array(value.utf8.prefix(10))
        if digits.count == 10, digits[4] == UInt8(ascii: "-"), digits[7] == UInt8(ascii: "-"),
           digits.enumerated().allSatisfy({ $0.offset == 4 || $0.offset == 7 || (0x30 ... 0x39).contains($0.element) })
        {
            return true
        }
        return false
    }
}
