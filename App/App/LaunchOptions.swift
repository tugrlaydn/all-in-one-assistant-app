import Foundation

/// Command-line options. The only one is `--vault <path>`, honoured in debug builds only (§8.6):
/// it opens a fixture or stress vault, shows the TEST VAULT badge, and turns off notifications and
/// launch-at-login. A release build ignores it, so the owner's app can never be pointed elsewhere.
struct LaunchOptions: Equatable {
    static let vaultFlag = "--vault"

    /// The vault to open instead of the owner's, or nil for the normal one.
    let testVault: URL?

    var isTestVault: Bool { testVault != nil }
    var notificationsEnabled: Bool { !isTestVault }
    var launchAtLoginEnabled: Bool { !isTestVault }

    init(
        arguments: [String],
        allowsTestVault: Bool,
        currentDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) {
        guard allowsTestVault, let path = Self.value(of: Self.vaultFlag, in: arguments), !path.isEmpty else {
            testVault = nil
            return
        }
        let expanded = (path as NSString).expandingTildeInPath
        // Append rather than `relativeTo:` — a base URL without a trailing slash counts as a file.
        let url = expanded.hasPrefix("/")
            ? URL(fileURLWithPath: expanded)
            : currentDirectory.appendingPathComponent(expanded)
        testVault = url.standardizedFileURL
    }

    /// Accepts `--vault <path>` and `--vault=<path>`; the last occurrence wins.
    private static func value(of flag: String, in arguments: [String]) -> String? {
        var result: String?
        var index = arguments.startIndex
        while index < arguments.endIndex {
            let argument = arguments[index]
            if argument == flag, arguments.index(after: index) < arguments.endIndex {
                index = arguments.index(after: index)
                result = arguments[index]
            } else if argument.hasPrefix(flag + "=") {
                result = String(argument.dropFirst(flag.count + 1))
            }
            index = arguments.index(after: index)
        }
        return result
    }
}
