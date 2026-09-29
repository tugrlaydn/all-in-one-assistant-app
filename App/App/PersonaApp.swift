import SwiftUI

@main
struct PersonaApp: App {
    static let mainWindowID = "main"

    private let launch: LaunchOptions
    @State private var session: VaultSession

    init() {
        BuildFlavor.checkSeparation()
        let launch = LaunchOptions(arguments: CommandLine.arguments, allowsTestVault: BuildFlavor.isDebug)
        self.launch = launch
        _session = State(initialValue: VaultSession(launch: launch))
    }

    var body: some Scene {
        Window("Persona", id: Self.mainWindowID) {
            MainWindow(launch: launch, session: session)
                .task { await session.openOnLaunch() }
        }
        .defaultSize(width: 1280, height: 760)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Choose Vault…") { session.chooseVault() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("Persona", systemImage: "sun.horizon") {
            MenuBarContent()
        }
    }
}
