import DesignKit
import SwiftUI

/// The one window. In P0 it shows the placeholder Horizon; the real one arrives in P2.
struct MainWindow: View {
    let launch: LaunchOptions

    var body: some View {
        HorizonPlaceholderView()
            .frame(minWidth: Spacing.minimumWindowWidth, minHeight: Spacing.minimumWindowHeight)
            .background(Palette.windowBackground)
            .navigationTitle(launch.isTestVault ? "Persona — TEST VAULT" : "Persona")
            .navigationSubtitle(launch.testVault?.path ?? "")
            .toolbar {
                if launch.isTestVault {
                    ToolbarItem(placement: .navigation) {
                        TestVaultBadge()
                    }
                }
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
