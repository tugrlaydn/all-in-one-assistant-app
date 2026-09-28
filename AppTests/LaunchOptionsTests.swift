import Foundation
import Testing
@testable import Persona

@Suite("LaunchOptions")
struct LaunchOptionsTests {
    let cwd = URL(fileURLWithPath: "/tmp/persona-cwd")

    @Test func noFlagMeansTheOwnersVault() {
        let options = LaunchOptions(arguments: ["Persona"], allowsTestVault: true, currentDirectory: cwd)
        #expect(options.testVault == nil)
        #expect(options.notificationsEnabled)
        #expect(options.launchAtLoginEnabled)
    }

    @Test func releaseBuildsIgnoreTheFlag() {
        let options = LaunchOptions(arguments: ["Persona", "--vault", "/tmp/v"], allowsTestVault: false)
        #expect(options.testVault == nil)
    }

    @Test(arguments: [["--vault", "/tmp/v"], ["--vault=/tmp/v"], ["--vault", "/tmp/other", "--vault", "/tmp/v"]])
    func acceptsBothSpellingsAndTheLastOneWins(_ flags: [String]) {
        let options = LaunchOptions(arguments: ["Persona"] + flags, allowsTestVault: true, currentDirectory: cwd)
        #expect(options.testVault?.path == "/tmp/v")
        #expect(!options.notificationsEnabled)
        #expect(!options.launchAtLoginEnabled)
    }

    @Test func relativePathsResolveAgainstTheWorkingDirectory() {
        let options = LaunchOptions(arguments: ["Persona", "--vault", "fixtures/../v"], allowsTestVault: true, currentDirectory: cwd)
        #expect(options.testVault?.path == "/tmp/persona-cwd/v")
    }

    @Test(arguments: [["--vault"], ["--vault="]])
    func missingValueIsIgnored(_ flags: [String]) {
        let options = LaunchOptions(arguments: ["Persona"] + flags, allowsTestVault: true, currentDirectory: cwd)
        #expect(options.testVault == nil)
    }
}

@Suite("BuildFlavor")
struct BuildFlavorTests {
    @Test func flavourAndBundleIdMustAgree() {
        #expect(BuildFlavor.isSeparated(isDebug: true, bundleIdentifier: "com.x.persona.debug"))
        #expect(BuildFlavor.isSeparated(isDebug: false, bundleIdentifier: "com.x.persona"))
        #expect(!BuildFlavor.isSeparated(isDebug: true, bundleIdentifier: "com.x.persona"))
        #expect(!BuildFlavor.isSeparated(isDebug: false, bundleIdentifier: "com.x.persona.debug"))
    }

    @Test func testsRunInsideTheDebugApp() {
        #expect(BuildFlavor.isDebug)
        #expect(Bundle.main.bundleIdentifier?.hasSuffix(BuildFlavor.debugSuffix) == true)
    }
}
