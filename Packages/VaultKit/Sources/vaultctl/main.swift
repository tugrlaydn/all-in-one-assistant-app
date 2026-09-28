import Foundation
import VaultKit

// vaultctl <folder> [--rebuild] — prints a summary of a vault's index (`make vault-dump`).
// Opens the folder read-only: it never writes a file, a folder or the index cache.

let arguments = CommandLine.arguments.dropFirst()
guard let path = arguments.first(where: { !$0.hasPrefix("--") }) else {
    FileHandle.standardError.write(Data("usage: vaultctl <vault folder> [--rebuild]\n".utf8))
    exit(64)
}
let root = URL(fileURLWithPath: path).standardizedFileURL

do {
    let vault = try Vault(root: root, readOnly: true)
    let report = try await vault.load(useCache: !arguments.contains("--rebuild"))
    print(VaultSummary.render(index: await vault.index, report: report, root: root.path), terminator: "")
} catch {
    FileHandle.standardError.write(Data("vaultctl: \(error)\n".utf8))
    exit(1)
}
