import SwiftUI

@main
struct PersonaApp: App {
    static let mainWindowID = "main"

    private let launch: LaunchOptions

    init() {
        BuildFlavor.checkSeparation()
        launch = LaunchOptions(arguments: CommandLine.arguments, allowsTestVault: BuildFlavor.isDebug)
    }

    var body: some Scene {
        Window("Persona", id: Self.mainWindowID) {
            MainWindow(launch: launch)
        }
        .defaultSize(width: 1280, height: 760)

        MenuBarExtra("Persona", systemImage: "sun.horizon") {
            MenuBarContent()
        }
    }
}
