import AppKit
import SwiftUI

/// Colour tokens (§6 identity 2). Colour encodes *kind*, never decoration.
///
/// P0 placeholders built from system colours so light/dark and accessibility contrast work from day one.
/// The accent (D3) and the kind colours are Tier A: they are replaced by the ratified Figma values in P2.
public enum Palette {
    // Identity
    public static let accent = Color.accentColor

    // Kinds
    public static let note = Color.indigo
    public static let task = Color.blue

    // Habit categories — the five fixed ones from SPEC.
    public static let physical = Color.green
    public static let creative = Color.pink
    public static let knowledge = Color.orange
    public static let mindset = Color.teal
    public static let monetizable = Color.yellow

    // Surfaces and text
    public static let windowBackground = Color(nsColor: .windowBackgroundColor)
    public static let column = Color(nsColor: .controlBackgroundColor)
    public static let focusedColumn = Color(nsColor: .textBackgroundColor)
    public static let separator = Color(nsColor: .separatorColor)
    public static let primaryText = Color.primary
    public static let secondaryText = Color.secondary

    // Safety — the debug build's TEST VAULT badge (§8.6). Always red, never themed.
    public static let testVaultBadge = Color.red
    public static let onTestVaultBadge = Color.white
}
