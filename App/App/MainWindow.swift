import DesignKit
import SwiftUI

/// The one window. It still shows the placeholder Horizon — the real one waits for the Figma frames (P2).
struct MainWindow: View {
    let launch: LaunchOptions
    let session: VaultSession

    var body: some View {
        HorizonPlaceholderView()
            .frame(minWidth: Spacing.minimumWindowWidth, minHeight: Spacing.minimumWindowHeight)
            .background(Palette.windowBackground)
            .navigationTitle(launch.isTestVault ? "Persona — TEST VAULT" : "Persona")
            .navigationSubtitle(subtitle)
            .toolbar {
                if launch.isTestVault {
                    ToolbarItem(placement: .navigation) {
                        TestVaultBadge()
                    }
                }
            }
    }
}

extension MainWindow {
    /// Plain window-subtitle text: which vault is open, or what to do.
    var subtitle: String {
        switch session.state {
        case .noVault: "No vault — File → Choose Vault…"
        case let .open(url): "\(url.lastPathComponent) · \(session.index.count) files"
        case let .failed(reason): "Couldn’t open the vault: \(reason)"
        }
    }
}

/// Red, unmissable, and only ever shown when a debug build was launched with `--vault` (§8.6).
struct TestVaultBadge: View {
    var body: some View {
        Text("TEST VAULT")
            .font(Typography.meta.weight(.bold))
            .foregroundStyle(Palette.onTestVaultBadge)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs / 2)
            .background(Palette.testVaultBadge, in: Capsule())
            .accessibilityLabel("Test vault — not your real data")
    }
}
