import SwiftUI
import Combine

/// Observable settings persisted via UserDefaults.
final class AppSettings: ObservableObject {
    @Published var zoomLevel: Double {
        didSet { UserDefaults.standard.set(zoomLevel, forKey: "zoomLevel") }
    }
    @Published var useNativeTitleBar: Bool {
        didSet { UserDefaults.standard.set(useNativeTitleBar, forKey: "useNativeTitleBar") }
    }
    @Published var enableSpellChecking: Bool {
        didSet { UserDefaults.standard.set(enableSpellChecking, forKey: "enableSpellChecking") }
    }
    @Published var blockTrackers: Bool {
        didSet { UserDefaults.standard.set(blockTrackers, forKey: "blockTrackers") }
    }
    @Published var customUserAgent: Bool {
        didSet { UserDefaults.standard.set(customUserAgent, forKey: "customUserAgent") }
    }

    init() {
        let defaults = UserDefaults.standard
        self.zoomLevel = defaults.object(forKey: "zoomLevel") as? Double ?? 1.0
        self.useNativeTitleBar = defaults.object(forKey: "useNativeTitleBar") as? Bool ?? true
        self.enableSpellChecking = defaults.object(forKey: "enableSpellChecking") as? Bool ?? true
        self.blockTrackers = defaults.object(forKey: "blockTrackers") as? Bool ?? true
        self.customUserAgent = defaults.object(forKey: "customUserAgent") as? Bool ?? true
    }
}