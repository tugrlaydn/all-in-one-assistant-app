import Foundation

/// Committed fixtures in `Tests/Fixtures/` — the only test data in the repo (§8.6).
/// Tests read them in place; a test that writes copies a vault into the temp directory first.
enum Fixtures {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures")

    static func url(_ relativePath: String) -> URL {
        root.appendingPathComponent(relativePath)
    }

    static func data(_ relativePath: String) throws -> Data {
        try Data(contentsOf: url(relativePath))
    }

    static func text(_ relativePath: String) throws -> String {
        guard let text = try String(validating: data(relativePath), as: UTF8.self) else {
            throw FixtureError.invalidUTF8(relativePath)
        }
        return text
    }

    /// Every file under a fixture vault, relative paths, sorted; dot-files skipped.
    static func files(inVault name: String) -> [String] {
        let base = url("Vaults/\(name)")
        let enumerator = FileManager.default.enumerator(at: base, includingPropertiesForKeys: [.isRegularFileKey])
        var paths: [String] = []
        while let item = enumerator?.nextObject() as? URL {
            guard (try? item.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                  !item.lastPathComponent.hasPrefix(".")
            else { continue }
            paths.append(String(item.path.dropFirst(base.path.count + 1)))
        }
        return paths.sorted()
    }

    /// A private copy of a fixture vault in the temp directory. Delete it with `removeCopy`.
    static func copyVault(_ name: String) throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("persona-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.copyItem(at: url("Vaults/\(name)"), to: destination)
        return destination
    }

    static func removeCopy(_ copy: URL) {
        precondition(copy.path.hasPrefix(FileManager.default.temporaryDirectory.path), "only temp copies are deleted")
        try? FileManager.default.removeItem(at: copy)
    }
}

enum FixtureError: Error {
    case invalidUTF8(String)
}
