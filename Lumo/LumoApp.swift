import SwiftUI

@main
struct LumoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We manage windows manually via AppDelegate for full control.
        // This empty scene is required by SwiftUI's App protocol.
        Settings {
            SettingsView()
                .environmentObject(appDelegate.settings)
        }
    }
}