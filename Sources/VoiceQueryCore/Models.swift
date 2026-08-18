import Foundation

public enum QueryMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case light
    case structured

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .light:
            return "轻度整理"
        case .structured:
            return "Query 整理"
        }
    }
}

public struct NormalizationResult: Codable, Equatable, Sendable {
    public let query: String
    public let ambiguities: [String]
    public let preservedLiterals: [String]
    public let shouldPreview: Bool

    public init(
        query: String,
        ambiguities: [String],
        preservedLiterals: [String],
        shouldPreview: Bool
    ) {
        self.query = query
        self.ambiguities = ambiguities
        self.preservedLiterals = preservedLiterals
        self.shouldPreview = shouldPreview
    }

    enum CodingKeys: String, CodingKey {
        case query
        case ambiguities
        case preservedLiterals = "preserved_literals"
        case shouldPreview = "should_preview"
    }
}

public struct LiteralValidation: Equatable, Sendable {
    public let sourceLiterals: [String]
    public let missingLiterals: [String]
    public let missingNegations: [String]

    public var isSafe: Bool {
        missingLiterals.isEmpty && missingNegations.isEmpty
    }

    public init(
        sourceLiterals: [String],
        missingLiterals: [String],
        missingNegations: [String]
    ) {
        self.sourceLiterals = sourceLiterals
        self.missingLiterals = missingLiterals
        self.missingNegations = missingNegations
    }
}

public struct LatencySnapshot: Equatable, Sendable {
    public var releaseToTranscriptMilliseconds: Double?
    public var normalizationMilliseconds: Double?
    public var releaseToReadyMilliseconds: Double?

    public init(
        releaseToTranscriptMilliseconds: Double? = nil,
        normalizationMilliseconds: Double? = nil,
        releaseToReadyMilliseconds: Double? = nil
    ) {
        self.releaseToTranscriptMilliseconds = releaseToTranscriptMilliseconds
        self.normalizationMilliseconds = normalizationMilliseconds
        self.releaseToReadyMilliseconds = releaseToReadyMilliseconds
    }
}

public enum VoiceQueryError: LocalizedError, Sendable {
    case missingAPIKey
    case microphonePermissionDenied
    case invalidAudioFormat
    case websocketNotConnected
    case server(String)
    case invalidResponse
    case requestTimedOut
    case invalidEndpoint(String)
    case accessibilityPermissionMissing
    case secureInputField
    case noFocusedInput

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先在设置中保存 OpenAI API Key。"
        case .microphonePermissionDenied:
            return "没有麦克风权限。请在系统设置中授权。"
        case .invalidAudioFormat:
            return "无法创建 24 kHz 单声道音频流。"
        case .websocketNotConnected:
            return "实时转写连接尚未建立。"
        case .server(let message):
            return "云端服务返回错误：\(message)"
        case .invalidResponse:
            return "云端返回了无法解析的结果。"
        case .requestTimedOut:
            return "云端处理超时，已改用本地降级结果。"
        case .invalidEndpoint(let message):
            return "云端接口配置无效：\(message)"
        case .accessibilityPermissionMissing:
            return "缺少辅助功能权限，无法写入其他应用。"
        case .secureInputField:
            return "安全输入框中已禁用 VoiceQuery。"
        case .noFocusedInput:
            return "没有找到当前输入框。"
        }
    }
}
