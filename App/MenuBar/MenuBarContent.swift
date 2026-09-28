import AppKit
import SwiftUI

/// The menu-bar extra. P0: a placeholder icon, open the window, quit.
struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Persona") {
            openWindow(id: PersonaApp.mainWindowID)
            NSApp.activate()
        }
        Divider()
        Button("Quit Persona") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
