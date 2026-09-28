import Foundation

/// Which build this is, and the guarantee that a debug build is a different app to macOS (§8.6).
///
/// The debug configuration uses the bundle id `…persona.debug`, so it gets its own UserDefaults
/// domain, its own sandbox container and therefore its own vault bookmark. `checkSeparation()`
/// refuses to launch if that ever stops being true.
enum BuildFlavor {
    static let debugSuffix = ".debug"

    static var isDebug: Bool {
        #if DEBUG
            true
        #else
            false
        #endif
    }

    static func isSeparated(isDebug: Bool, bundleIdentifier: String) -> Bool {
        isDebug == bundleIdentifier.hasSuffix(debugSuffix)
    }

    static func checkSeparation(bundle: Bundle = .main) {
        let identifier = bundle.bundleIdentifier ?? ""
        precondition(
            isSeparated(isDebug: isDebug, bundleIdentifier: identifier),
            "Build flavour and bundle id disagree (\(identifier)); a debug build could reach the owner's settings."
        )
    }
}
