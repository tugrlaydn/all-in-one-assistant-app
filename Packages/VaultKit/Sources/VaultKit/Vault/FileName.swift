import Foundation

/// File names from titles (FORMAT §4.1): `<Title slug>.md`, collisions get `-2`, `-3`.
///
/// The slug keeps the title readable — spaces, case and non-Latin letters stay — and replaces only
/// what macOS, iOS, Windows and Obsidian cannot use in a file name.
public enum FileName {
    static let forbidden: Set<Character> = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", "#", "^", "[", "]"]
    /// Bytes, not characters: file systems limit names to 255 bytes; this leaves room for `-NN.md`.
    static let maxBytes = 200

    public static func slug(_ title: String) -> String {
        var result = ""
        var lastWasSpace = false
        for char in title {
            let replacement: Character = forbidden.contains(char) || char.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) ? "-" : char
            if replacement.isWhitespace {
                if !lastWasSpace, !result.isEmpty { result.append(" ") }
                lastWasSpace = true
            } else {
                result.append(replacement)
                lastWasSpace = false
            }
        }
        result = result.trimmingCharacters(in: .whitespaces)
        while result.hasPrefix(".") { result.removeFirst() }
        result = result.trimmingCharacters(in: .whitespaces)
        while result.utf8.count > maxBytes { result.removeLast() }
        result = result.trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? "Untitled" : result
    }

    /// `<slug>.md`, or `<slug>-2.md`, `-3`… — the first name not in `taken`.
    /// Comparison ignores case and Unicode normalisation, like APFS.
    public static func available(for title: String, taken: Set<String>) -> String {
        let base = slug(title)
        let folded = Set(taken.map(key))
        var candidate = base + ".md"
        var number = 2
        while folded.contains(key(candidate)) {
            candidate = "\(base)-\(number).md"
            number += 1
        }
        return candidate
    }

    /// Does `fileName` already belong to `title` — `Send invoice.md` or `Send invoice-3.md`?
    /// Then a save keeps it instead of renaming.
    public static func matches(_ fileName: String, title: String) -> Bool {
        let base = key(slug(title))
        var name = key(fileName)
        guard name.hasSuffix(".md") else { return false }
        name.removeLast(3)
        if name == base { return true }
        guard name.hasPrefix(base + "-") else { return false }
        let suffix = name.dropFirst(base.count + 1)
        return !suffix.isEmpty && suffix.allSatisfy(\.isNumber) && (Int(suffix) ?? 0) >= 2
    }

    static func key(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping.lowercased()
    }
}
