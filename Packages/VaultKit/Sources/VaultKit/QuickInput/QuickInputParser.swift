import Foundation

/// What one line of Quick Input means (grammar §5, A16). A pure function of the text, the day and
/// the default kind, so the floating panel, ⌘K and the notification text field can never disagree.
public struct QuickInput: Equatable, Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        case task, note, habitLog, command
    }

    public var kind: Kind
    /// Task or note title; for a habit log, the habit to fuzzy-match; for a command, its arguments.
    public var title: String
    /// Task `scheduled`, or a habit log's entry date.
    public var scheduled: Day?
    public var due: Day?
    public var tags: [String] = []
    public var priority: Int?
    public var estimate: Estimate?
    /// Parent task title to fuzzy-match (`>Q4 invoicing`).
    public var parent: String?
    /// `[[links]]` — also left in `title`, because they belong to the text.
    public var links: [WikiLink] = []
    /// Habit log minutes (`h swim 45`).
    public var minutes: Int?
    /// Habit log note (`h swim 45 evening` → "evening").
    public var note: String = ""
    /// Command name without the slash (`/open x` → "open").
    public var command: String?
    /// Everything recognised, with its place in the input — for the chips shown while typing.
    public var tokens: [QuickInputToken] = []
}

public struct QuickInputToken: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case kind, scheduled, due, tag, priority, estimate, parent, link, minutes, command
    }

    public let kind: Kind
    public let range: Range<String.Index>
    public let text: String
}

public enum QuickInputParser {
    /// Parses one line. `today` anchors `@today`, `@fri`, `@+3d`; `defaultKind` applies without a prefix.
    public static func parse(_ input: String, today: Day, defaultKind: QuickInput.Kind = .task) -> QuickInput {
        let line = input.replacingOccurrences(of: "\n", with: " ")
        var result = QuickInput(kind: defaultKind == .command ? .task : defaultKind, title: "")
        var start = line.startIndex
        while start < line.endIndex, line[start].isWhitespace { start = line.index(after: start) }

        // Prefix: `t `, `n `, `h ` (or the letter alone), or `/`.
        if start < line.endIndex, line[start] == "/" {
            return parseCommand(line, from: start)
        }
        if start < line.endIndex {
            let letter = line[start]
            let next = line.index(after: start)
            let prefixEnds = next == line.endIndex || line[next].isWhitespace
            let kinds: [Character: QuickInput.Kind] = ["t": .task, "n": .note, "h": .habitLog]
            if prefixEnds, let kind = kinds[letter] {
                result.kind = kind
                result.tokens.append(QuickInputToken(kind: .kind, range: start ..< next, text: String(letter)))
                start = next
            }
        }

        let words = tokenize(line, from: start)
        var textWords: [Word] = []
        var index = 0
        while index < words.count {
            let word = words[index]
            index += 1
            if let consumed = recognise(word, following: words[index...], kind: result.kind, today: today, into: &result) {
                index += consumed
            } else {
                textWords.append(word)
            }
        }

        if result.kind == .habitLog {
            splitHabitLog(textWords, into: &result)
        } else {
            result.title = textWords.map(\.text).joined(separator: " ")
        }
        result.tokens.sort { $0.range.lowerBound < $1.range.lowerBound }
        return result
    }

    // MARK: Words

    struct Word {
        let text: String
        let range: Range<String.Index>
    }

    /// Splits on whitespace; a closed `[[…]]` is one word even with spaces inside.
    static func tokenize(_ line: String, from start: String.Index) -> [Word] {
        var words: [Word] = []
        var index = start
        while index < line.endIndex {
            if line[index].isWhitespace {
                index = line.index(after: index)
                continue
            }
            let wordStart = index
            while index < line.endIndex, !line[index].isWhitespace {
                if line[index...].hasPrefix("[["), let close = line[index...].range(of: "]]") {
                    index = close.upperBound
                } else {
                    index = line.index(after: index)
                }
            }
            words.append(Word(text: String(line[wordStart ..< index]), range: wordStart ..< index))
        }
        return words
    }

    /// Returns how many *following* words the token consumed (0 for a one-word token), or nil when
    /// `word` is plain text for this kind of input — unknown text is never eaten. The first date,
    /// priority, estimate or parent wins; a second one stays in the title rather than vanish.
    static func recognise(
        _ word: Word, following: ArraySlice<Word>, kind: QuickInput.Kind, today: Day, into result: inout QuickInput
    ) -> Int? {
        let text = word.text
        let isTask = kind == .task
        func token(_ tokenKind: QuickInputToken.Kind) {
            result.tokens.append(QuickInputToken(kind: tokenKind, range: word.range, text: text))
        }

        if isTask, result.due == nil, text.lowercased().hasPrefix("@due:"), let day = date(String(text.dropFirst(5)), today: today) {
            result.due = day
            token(.due)
            return 0
        }
        if isTask || kind == .habitLog, result.scheduled == nil, text.hasPrefix("@"), let day = date(String(text.dropFirst()), today: today) {
            result.scheduled = day
            token(.scheduled)
            return 0
        }
        if isTask || kind == .note, text.hasPrefix("#"), text.count > 1 {
            let tag = String(text.dropFirst())
            if tag.allSatisfy(MarkdownText.isTagCharacter), tag.contains(where: { !$0.isNumber }) {
                if !result.tags.contains(where: { $0.lowercased() == tag.lowercased() }) { result.tags.append(tag) }
                token(.tag)
                return 0
            }
        }
        if isTask, result.priority == nil, text.count == 2, text.hasPrefix("!"), let value = Int(text.dropFirst()), (1 ... 3).contains(value) {
            result.priority = value
            token(.priority)
            return 0
        }
        if isTask, result.estimate == nil, text.hasPrefix("~"), let estimate = Estimate(text.dropFirst()), text.dropFirst().first?.isNumber == true {
            result.estimate = estimate
            token(.estimate)
            return 0
        }
        // `>Parent title` runs to the next token or the end; a lone `>` is just text (`a > b`).
        if isTask, result.parent == nil, text.hasPrefix(">"), text.count > 1 {
            var parts = [String(text.dropFirst())]
            var consumed = 0
            var end = word.range.upperBound
            for next in following {
                guard !looksLikeToken(next.text) else { break }
                parts.append(next.text)
                end = next.range.upperBound
                consumed += 1
            }
            result.parent = parts.joined(separator: " ")
            result.tokens.append(QuickInputToken(kind: .parent, range: word.range.lowerBound ..< end, text: ">" + result.parent!))
            return consumed
        }
        if isTask || kind == .note, let link = WikiLink(parsing: text) {
            result.links.append(link)
            token(.link)
            return nil // the link also stays in the text
        }
        return nil
    }

    static func looksLikeToken(_ text: String) -> Bool {
        guard let first = text.first else { return false }
        return "@#!~>".contains(first) || text.hasPrefix("[[")
    }

    // MARK: Dates

    static let weekdays = ["mon": 1, "tue": 2, "wed": 3, "thu": 4, "fri": 5, "sat": 6, "sun": 7]

    /// `today`, `tom`, `mon`…`sun` (the next one, today included), `2026-10-03`, `+3d`.
    static func date(_ text: String, today: Day) -> Day? {
        let lower = text.lowercased()
        switch lower {
        case "today": return today
        case "tom": return today.adding(days: 1)
        default: break
        }
        if let weekday = weekdays[lower] {
            return today.adding(days: (weekday - today.weekday + 7) % 7)
        }
        if let day = Day(lower) {
            return day
        }
        if lower.hasPrefix("+"), lower.hasSuffix("d"), let count = Int(lower.dropFirst().dropLast()), (0 ... 36_600).contains(count) {
            return today.adding(days: count)
        }
        return nil
    }

    // MARK: Habit logs and commands

    /// `swim 45 evening` → habit "swim", 45 minutes, note "evening". The first number splits the line.
    static func splitHabitLog(_ words: [Word], into result: inout QuickInput) {
        guard let index = words.firstIndex(where: { minutes($0.text) != nil }) else {
            result.title = words.map(\.text).joined(separator: " ")
            return
        }
        result.minutes = minutes(words[index].text)
        result.tokens.append(QuickInputToken(kind: .minutes, range: words[index].range, text: words[index].text))
        result.title = words[..<index].map(\.text).joined(separator: " ")
        result.note = words[(index + 1)...].map(\.text).joined(separator: " ")
    }

    /// `45`, `45m`, `1h`, `1h30m`.
    static func minutes(_ text: String) -> Int? {
        guard text.first?.isNumber == true, let estimate = Estimate(text) else { return nil }
        return estimate.minutes
    }

    static func parseCommand(_ line: String, from slash: String.Index) -> QuickInput {
        let nameStart = line.index(after: slash)
        let nameEnd = line[nameStart...].firstIndex(where: \.isWhitespace) ?? line.endIndex
        let name = String(line[nameStart ..< nameEnd])
        let args = line[nameEnd...].trimmingCharacters(in: .whitespaces)
        var result = QuickInput(kind: .command, title: args)
        result.command = name
        result.tokens = [QuickInputToken(kind: .command, range: slash ..< nameEnd, text: String(line[slash ..< nameEnd]))]
        return result
    }
}
