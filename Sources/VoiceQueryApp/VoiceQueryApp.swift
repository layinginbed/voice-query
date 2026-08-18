import AppKit
import SwiftUI
import VoiceQueryCore

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let settings: SettingsStore
    let model: AppModel

    private init() {
        let settings = SettingsStore()
        self.settings = settings
        self.model = AppModel(settings: settings)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        hotKey = GlobalHotKey(
            onPress: {
                Task { @MainActor in
                    await AppEnvironment.shared.model.beginPress()
                }
            },
            onRelease: {
                Task { @MainActor in
                    await AppEnvironment.shared.model.endPress()
                }
            }
        )
    }
}

@main
struct VoiceQueryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings: SettingsStore
    @StateObject private var model: AppModel

    init() {
        let environment = AppEnvironment.shared
        _settings = StateObject(wrappedValue: environment.settings)
        _model = StateObject(wrappedValue: environment.model)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model, settings: settings)
        } label: {
            Image(systemName: model.state.isRecording ? "mic.fill" : "waveform")
                .accessibilityLabel("VoiceQuery")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings)
        }
        .windowResizability(.contentSize)
    }
}
