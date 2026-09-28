import Foundation

/// A value read from front matter. Only what the vault format uses: scalars, lists of scalars, and
/// one level of key → scalar maps. Anything deeper is preserved in the file but not interpreted.
public enum YAMLValue: Equatable, Sendable {
    case null
    case scalar(String)
    case list([String])
    case map([YAMLPair])
}

public struct YAMLPair: Equatable, Sendable {
    public var key: String
    public var value: String?

    public init(_ key: String, _ value: String?) {
        self.key = key
        self.value = value
    }
}

/// The YAML front matter of a Markdown file, kept line by line (A07, FORMAT §4.5).
///
/// Reading never changes anything. Writing a key rewrites only that key's line(s): its indentation,
/// trailing comment and list style are kept; every other line — unknown keys, comments, blank lines,
/// ordering — stays byte-for-byte as it was.
public struct FrontMatter: Equatable, Sendable {
    var opening: Line
    var lines: [Line]
    var closing: Line

    init(opening: Line, lines: [Line], closing: Line) {
        self.opening = opening
        self.lines = lines
        self.closing = closing
    }

    /// An empty block (`---` / `---`) for a new file.
    public init(lineEnding: String = "\n") {
        self.init(
            opening: Line(content: "---", ending: lineEnding),
            lines: [],
            closing: Line(content: "---", ending: lineEnding)
        )
    }

    var text: String {
        opening.raw + lines.map(\.raw).joined() + closing.raw
    }

    var lineEnding: String {
        opening.ending.isEmpty ? "\n" : opening.ending
    }

    // MARK: Reading

    /// Top-level keys in file order.
    public var keys: [String] {
        entries().map(\.key)
    }

    public func contains(_ key: String) -> Bool {
        entry(for: key) != nil
    }

    public func value(_ key: String) -> YAMLValue {
        guard let entry = entry(for: key) else { return .null }
        return value(of: entry)
    }

    /// A scalar, or nil for a missing or empty key. Lists and maps are not strings.
    public func string(_ key: String) -> String? {
        if case let .scalar(text) = value(key) { return text }
        return nil
    }

    /// A list; a single scalar counts as a one-item list (`tags: work`).
    public func list(_ key: String) -> [String] {
        switch value(key) {
        case let .list(items): items
        case let .scalar(text): [text]
        case .null, .map: []
        }
    }

    public func map(_ key: String) -> [YAMLPair] {
        if case let .map(pairs) = value(key) { return pairs }
        return []
    }

    public func int(_ key: String) -> Int? {
        string(key).flatMap { Int($0) }
    }

    public func bool(_ key: String) -> Bool? {
        switch string(key)?.lowercased() {
        case "true", "yes", "on": true
        case "false", "no", "off": false
        default: nil
        }
    }

    // MARK: Writing

    /// Sets `key`, rewriting only its lines; appends it at the end if it is new.
    public mutating func set(_ key: String, _ value: YAMLValue, as style: YAMLScalarStyle = .text) {
        guard let entry = entry(for: key) else {
            lines += render(key: key, value, style: style, like: nil)
            return
        }
        lines.replaceSubrange(entry.range, with: render(key: key, value, style: style, like: entry))
    }

    /// Sets one key of a block map (`plan:` → `physical: "[[Swimming]]"`), touching only that line.
    public mutating func setMapValue(_ key: String, _ subkey: String, _ value: String?, as style: YAMLScalarStyle = .text) {
        guard let entry = entry(for: key) else {
            set(key, .map([YAMLPair(subkey, value)]), as: style)
            return
        }
        let keyLine = KeyLine(lines[entry.range.lowerBound])!
        let isBlockMap = switch self.value(of: entry) {
        case .map, .null: keyLine.value.isEmpty
        case .scalar, .list: false
        }
        guard isBlockMap else {
            // Flow map, list or scalar: rewrite the whole entry.
            var pairs = map(key)
            if let index = pairs.firstIndex(where: { $0.key == subkey }) {
                pairs[index].value = value
            } else {
                pairs.append(YAMLPair(subkey, value))
            }
            set(key, .map(pairs), as: style)
            return
        }
        let body = entry.range.dropFirst()
        let subLines = body.filter { !lines[$0].isBlank && !lines[$0].content.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
        let indent = subLines.first.map { String(lines[$0].indentation) } ?? "  "
        let rendered = value.map { YAMLScalar.render($0, style: style) } ?? ""
        for index in subLines where lines[index].indentation == indent {
            guard var sub = KeyLine(lines[index], indent: indent), sub.key == subkey else { continue }
            sub.setValue(rendered)
            lines[index].content = sub.content
            return
        }
        let insertAt = (subLines.last ?? entry.range.lowerBound) + 1
        let content = indent + KeyLine.keyText(subkey) + ":" + (rendered.isEmpty ? "" : " " + rendered)
        lines.insert(Line(content: content, ending: lineEnding), at: insertAt)
    }

    // MARK: Entries

    struct Entry {
        let key: String
        /// Line indices: the key line plus its continuation lines.
        let range: Range<Int>
    }

    func entry(for key: String) -> Entry? {
        entries().first { $0.key == key }
    }

    func entries() -> [Entry] {
        var result: [Entry] = []
        var index = 0
        while index < lines.count {
            guard let keyLine = KeyLine(lines[index]) else {
                index += 1
                continue
            }
            var end = index + 1
            var scan = index + 1
            while scan < lines.count {
                let line = lines[scan]
                if line.isBlank {
                    scan += 1
                    continue
                }
                let isIndented = !line.indentation.isEmpty
                let isColumnZeroItem = keyLine.value.isEmpty && (line.content == "-" || line.content.hasPrefix("- "))
                guard isIndented || isColumnZeroItem else { break }
                scan += 1
                end = scan
            }
            result.append(Entry(key: keyLine.key, range: index ..< end))
            index = end
        }
        return result
    }

    private func value(of entry: Entry) -> YAMLValue {
        let keyLine = KeyLine(lines[entry.range.lowerBound])!
        let inline = keyLine.value
        let body = entry.range.dropFirst().map { lines[$0] }.filter {
            !$0.isBlank && !$0.content.trimmingCharacters(in: .whitespaces).hasPrefix("#")
        }
        if let first = inline.first {
            switch first {
            case "[" where inline.last == "]":
                return .list(YAMLScalar.splitFlow(inline.dropFirst().dropLast()).map { YAMLScalar.unquote($0) })
            case "{" where inline.last == "}":
                return .map(YAMLScalar.splitFlow(inline.dropFirst().dropLast()).map(Self.pair))
            case "|", ">":
                return .scalar(blockScalar(body: entry.range.dropFirst().map { lines[$0] }, folded: first == ">"))
            default:
                return .scalar(YAMLScalar.unquote(inline))
            }
        }
        guard let firstBody = body.first else { return .null }
        let firstTrimmed = firstBody.content.trimmingCharacters(in: .whitespaces)
        if firstTrimmed == "-" || firstTrimmed.hasPrefix("- ") {
            let itemIndent = firstBody.indentation
            return .list(body.compactMap { line -> String? in
                guard line.indentation == itemIndent else { return nil }
                let trimmed = line.content.drop { $0 == " " || $0 == "\t" }
                guard trimmed.hasPrefix("-") else { return nil }
                let parts = YAMLScalar.splitComment(trimmed.dropFirst())
                return YAMLScalar.unquote(parts.value)
            })
        }
        let subIndent = String(firstBody.indentation)
        return .map(body.compactMap { line in
            guard line.indentation == subIndent, let sub = KeyLine(line, indent: subIndent) else { return nil }
            return YAMLPair(sub.key, sub.value.isEmpty ? nil : YAMLScalar.unquote(sub.value))
        })
    }

    private static func pair(_ item: Substring) -> YAMLPair {
        guard let colon = item.firstIndex(of: ":") else { return YAMLPair(YAMLScalar.unquote(item), nil) }
        let value = item[item.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        return YAMLPair(YAMLScalar.unquote(item[..<colon]), value.isEmpty ? nil : YAMLScalar.unquote(value[...]))
    }

    private func blockScalar(body: [Line], folded: Bool) -> String {
        let indent = body.first { !$0.isBlank }?.indentation.count ?? 0
        let texts = body.map { $0.isBlank ? "" : String($0.content.dropFirst(indent)) }
        let trimmed = texts.reversed().drop { $0.isEmpty }.reversed()
        return trimmed.joined(separator: folded ? " " : "\n")
    }

    // MARK: Rendering

    private func render(key: String, _ value: YAMLValue, style: YAMLScalarStyle, like old: Entry?) -> [Line] {
        let ending = lineEnding
        var keyLine = old.flatMap { KeyLine(lines[$0.range.lowerBound]) } ?? KeyLine(key: key)
        let oldBody = old.map { Array(lines[$0.range.dropFirst()]) } ?? []

        switch value {
        case .null:
            keyLine.setValue("")
            return [Line(content: keyLine.content, ending: ending)]

        case let .scalar(text):
            keyLine.setValue(YAMLScalar.render(text, style: style))
            return [Line(content: keyLine.content, ending: ending)]

        case let .list(items):
            // Keep a block list block (Obsidian's style); everything else becomes a flow list.
            let firstItem = oldBody.first { $0.content.trimmingCharacters(in: .whitespaces).hasPrefix("-") }
            if keyLine.value.isEmpty, let firstItem, !items.isEmpty {
                keyLine.setValue("")
                let dash = firstItem.indentation + "- "
                return [Line(content: keyLine.content, ending: ending)] + items.map {
                    Line(content: dash + YAMLScalar.render($0, style: style), ending: ending)
                }
            }
            let flow = items.map { YAMLScalar.render($0, style: style, inFlow: true) }.joined(separator: ", ")
            keyLine.setValue("[" + flow + "]")
            return [Line(content: keyLine.content, ending: ending)]

        case let .map(pairs):
            // Reuse the old sub-key indentation only if the old value was itself a block map.
            var indent = "  "
            if let old, keyLine.value.isEmpty, case .map = self.value(of: old),
               let first = oldBody.first(where: { !$0.isBlank }), !first.indentation.isEmpty
            {
                indent = String(first.indentation)
            }
            keyLine.setValue("")
            return [Line(content: keyLine.content, ending: ending)] + pairs.map { pair in
                let rendered = pair.value.map { YAMLScalar.render($0, style: style) } ?? ""
                return Line(
                    content: indent + KeyLine.keyText(pair.key) + ":" + (rendered.isEmpty ? "" : " " + rendered),
                    ending: ending
                )
            }
        }
    }
}

/// `key: value   # comment`, split so the value can be replaced without disturbing the rest.
struct KeyLine {
    var indent: String
    var keyPart: String // everything up to and including the colon
    var key: String
    var leading: String // whitespace between the colon and the value
    var value: Substring
    var trailing: String // whitespace + comment after the value

    var content: String {
        indent + keyPart + leading + value + trailing
    }

    init(key: String) {
        indent = ""
        keyPart = Self.keyText(key) + ":"
        self.key = key
        leading = ""
        value = ""
        trailing = ""
    }

    /// Parses a key line at exactly `indent` (top-level keys have none).
    init?(_ line: Line, indent: String = "") {
        let content = line.content
        guard content.hasPrefix(indent) else { return nil }
        let rest = content.dropFirst(indent.count)
        guard let first = rest.first, first != " ", first != "\t", first != "#", first != "-" else { return nil }

        var colon: Substring.Index?
        var key: String
        if first == "\"" || first == "'" {
            guard let close = rest.dropFirst().firstIndex(of: first) else { return nil }
            let after = rest.index(after: close)
            guard after < rest.endIndex, rest[after] == ":" else { return nil }
            colon = after
            key = YAMLScalar.unquote(rest[...close])
        } else {
            var index = rest.startIndex
            while index < rest.endIndex {
                if rest[index] == ":" {
                    let next = rest.index(after: index)
                    if next == rest.endIndex || rest[next] == " " || rest[next] == "\t" {
                        colon = index
                        break
                    }
                }
                index = rest.index(after: index)
            }
            guard let colon else { return nil }
            key = String(rest[..<colon]).trimmingCharacters(in: .whitespaces)
        }
        guard let colon, !key.isEmpty else { return nil }

        let afterColon = rest[rest.index(after: colon)...]
        let parts = YAMLScalar.splitComment(afterColon)
        self.indent = indent
        keyPart = String(rest[...colon])
        self.key = key
        value = parts.value
        if parts.value.isEmpty {
            // `done_at:        # comment`: the padding belongs to the comment, not to a value.
            leading = ""
            trailing = String(parts.leading) + String(parts.trailing)
        } else {
            leading = String(parts.leading)
            trailing = String(parts.trailing)
        }
    }

    /// Replaces the value; keeps the key, the trailing comment and its alignment.
    mutating func setValue(_ newValue: String) {
        if newValue.isEmpty {
            // `key:` then the comment, if any. Keep the comment's column when there was a value.
            let keptSpace = value.isEmpty ? leading : leading + String(repeating: " ", count: value.count)
            value = ""
            leading = trailing.isEmpty ? "" : keptSpace
        } else {
            if leading.isEmpty { leading = " " }
            if value.isEmpty, !trailing.isEmpty {
                // `done_at:        # comment` → `done_at: 2026-…  # comment`: eat into the padding.
                let padding = trailing.prefix { $0 == " " }
                let eat = min(padding.count - 1, newValue.count + 1)
                if eat > 0 { trailing = String(trailing.dropFirst(eat)) }
            }
            value = Substring(newValue)
        }
    }

    static func keyText(_ key: String) -> String {
        YAMLScalar.needsQuotes(key, style: .literal, inFlow: false) ? YAMLScalar.doubleQuoted(key) : key
    }
}
