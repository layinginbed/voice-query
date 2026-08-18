import Combine
import Foundation
import VoiceQueryCore

struct ValidatedCloudSettings {
    let responsesURL: URL
    let realtimeURL: URL
    let normalizerModel: String
    let transcriptionModel: String
}

@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let model = "normalizerModel"
        static let transcriptionModel = "transcriptionModel"
        static let responsesEndpoint = "responsesEndpoint"
        static let realtimeEndpoint = "realtimeEndpoint"
        static let mode = "queryMode"
        static let autoInsert = "autoInsert"
        static let transcriptionDelay = "transcriptionDelay"
    }

    private let defaults: UserDefaults
    private let keychain: KeychainStore

    @Published var apiKey: String
    @Published var model: String
    @Published var transcriptionModel: String
    @Published var responsesEndpoint: String
    @Published var realtimeEndpoint: String
    @Published var mode: QueryMode
    @Published var autoInsert: Bool
    @Published var transcriptionDelay: String
    @Published var saveMessage = ""

    init(
        defaults: UserDefaults = .standard,
        keychain: KeychainStore = KeychainStore()
    ) {
        self.defaults = defaults
        self.keychain = keychain
        self.apiKey = keychain.load()
        self.model = defaults.string(forKey: Keys.model) ?? "gpt-5.6"
        self.transcriptionModel = defaults.string(forKey: Keys.transcriptionModel)
            ?? "gpt-live-transcribe"
        self.responsesEndpoint = defaults.string(forKey: Keys.responsesEndpoint)
            ?? "https://api.openai.com/v1/responses"
        self.realtimeEndpoint = defaults.string(forKey: Keys.realtimeEndpoint)
            ?? "wss://api.openai.com/v1/realtime"
        self.mode = QueryMode(
            rawValue: defaults.string(forKey: Keys.mode) ?? "structured"
        ) ?? .structured
        self.autoInsert = defaults.object(forKey: Keys.autoInsert) as? Bool ?? false
        self.transcriptionDelay = defaults.string(forKey: Keys.transcriptionDelay) ?? "low"
    }

    func save() {
        do {
            _ = try validatedCloudSettings()
            try keychain.save(apiKey)
            defaults.set(model, forKey: Keys.model)
            defaults.set(transcriptionModel, forKey: Keys.transcriptionModel)
            defaults.set(responsesEndpoint, forKey: Keys.responsesEndpoint)
            defaults.set(realtimeEndpoint, forKey: Keys.realtimeEndpoint)
            defaults.set(mode.rawValue, forKey: Keys.mode)
            defaults.set(autoInsert, forKey: Keys.autoInsert)
            defaults.set(transcriptionDelay, forKey: Keys.transcriptionDelay)
            saveMessage = "设置已保存。API Key 仅存于本机 Keychain。"
        } catch {
            saveMessage = error.localizedDescription
        }
    }

    func validatedCloudSettings() throws -> ValidatedCloudSettings {
        ValidatedCloudSettings(
            responsesURL: try EndpointValidator.responsesURL(from: responsesEndpoint),
            realtimeURL: try EndpointValidator.realtimeURL(from: realtimeEndpoint),
            normalizerModel: try EndpointValidator.requireModel(model, label: "整理模型"),
            transcriptionModel: try EndpointValidator.requireModel(
                transcriptionModel,
                label: "实时转写模型"
            )
        )
    }

    func restoreOpenAIDefaults() {
        responsesEndpoint = "https://api.openai.com/v1/responses"
        realtimeEndpoint = "wss://api.openai.com/v1/realtime"
        transcriptionModel = "gpt-live-transcribe"
        model = "gpt-5.6"
        saveMessage = "已恢复 OpenAI 默认值，点击“保存设置”后生效。"
    }
}
