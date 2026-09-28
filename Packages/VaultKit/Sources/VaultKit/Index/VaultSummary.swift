import Foundation

/// A plain-text summary of a vault's index — what `vaultctl` (`make vault-dump`) prints.
public enum VaultSummary {
    public static func render(index: VaultIndex, report: LoadReport, root: String, maxDays: Int = 30) -> String {
        var lines: [String] = []
        let entries = index.entries.values.sorted { $0.path < $1.path }
        func count(_ kind: ItemKind?) -> Int { entries.filter { $0.kind == kind }.count }

        lines.append("Vault: \(root)")
        lines.append("Files: \(index.count) (notes \(count(.note)), tasks \(count(.task)), habits \(count(.habit)), "
            + "habit weeks \(count(.habitWeek)), category files \(count(.habitCategories)), unmanaged \(count(nil)))")
        lines.append("Loaded: \(report.parsed) parsed, \(report.fromCache) from cache, "
            + "\(report.placeholders.count) in iCloud only, \(report.unreadable.count) unreadable")
        for path in report.placeholders { lines.append("  in iCloud only: \(path)") }
        for path in report.unreadable { lines.append("  unreadable (not UTF-8, left alone): \(path)") }

        let statuses = TaskStatus.allCases.map { status in "\(entries.filter { $0.kind == .task && $0.status == status.rawValue }.count) \(status.rawValue)" }
        lines.append("Tasks: " + statuses.joined(separator: ", "))

        var tagCounts: [String: (display: String, count: Int)] = [:]
        for entry in entries {
            for tag in entry.tags { tagCounts[tag.lowercased(), default: (tag, 0)].count += 1 }
        }
        let tags = tagCounts.values.sorted { ($1.count, $0.display) < ($0.count, $1.display) }
        lines.append("Tags: " + (tags.isEmpty ? "none" : tags.map { "#\($0.display) (\($0.count))" }.joined(separator: ", ")))

        var unresolved: [String] = []
        for entry in entries {
            for target in entry.links + (entry.parent.map { [$0] } ?? []) where index.resolve(WikiLink(target)) == nil {
                unresolved.append("[[\(target)]] in \(entry.path)")
            }
        }
        lines.append("Unresolved links: " + (unresolved.isEmpty ? "none" : "\(unresolved.count)"))
        for link in unresolved { lines.append("  " + link) }

        let days = Set(entries.flatMap(\.days)).sorted()
        lines.append("Days with items: \(days.count)")
        for day in days.prefix(maxDays) {
            let items = index.items(on: day).map { "\($0.title) (\($0.kind?.rawValue ?? "unmanaged"))" }
            lines.append("  \(day)  " + items.joined(separator: ", "))
        }
        if days.count > maxDays { lines.append("  … \(days.count - maxDays) more days") }
        return lines.joined(separator: "\n") + "\n"
    }
}
