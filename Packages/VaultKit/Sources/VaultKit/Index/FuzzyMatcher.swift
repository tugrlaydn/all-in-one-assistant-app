import Foundation

/// Fuzzy title matching for search, `>Parent` and `h swim` lookups: the query's letters must appear
/// in order in the title. Higher scores for a prefix match, word starts and consecutive runs.
/// Case- and diacritic-insensitive (`cal` finds `Çalışma`).
struct FuzzyMatcher {
    private let query: [Character]

    init(_ query: String) {
        self.query = Array(Self.fold(query).filter { !$0.isWhitespace })
    }

    var isEmpty: Bool { query.isEmpty }

    func score(_ title: String) -> Int? {
        let folded = Self.fold(title)
        let chars = Array(folded)
        guard !query.isEmpty, !chars.isEmpty else { return nil }

        var score = 0
        var queryIndex = 0
        var previousMatch = -2
        for (index, char) in chars.enumerated() where queryIndex < query.count && char == query[queryIndex] {
            score += 1
            if index == 0 || !chars[index - 1].isLetter && !chars[index - 1].isNumber { score += 5 }
            if index == previousMatch + 1 { score += 3 }
            previousMatch = index
            queryIndex += 1
        }
        guard queryIndex == query.count else { return nil }

        let compactTitle = String(chars.filter { !$0.isWhitespace })
        if compactTitle == String(query) { score += 100 }
        else if compactTitle.hasPrefix(String(query)) { score += 20 }
        score -= (chars.count - query.count) / 4
        return score
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "ı", with: "i")
    }
}
