import Foundation

public enum EndpointValidator {
    public static func responsesURL(from value: String) throws -> URL {
        try validatedURL(
            from: value,
            secureScheme: "https",
            localScheme: "http",
            label: "整理接口"
        )
    }

    public static func realtimeURL(from value: String) throws -> URL {
        try validatedURL(
            from: value,
            secureScheme: "wss",
            localScheme: "ws",
            label: "Realtime WebSocket 接口"
        )
    }

    public static func requireModel(_ value: String, label: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VoiceQueryError.invalidEndpoint("\(label)不能为空")
        }
        return trimmed
    }

    private static func validatedURL(
        from value: String,
        secureScheme: String,
        localScheme: String,
        label: String
    ) throws -> URL {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased(),
              !host.isEmpty else {
            throw VoiceQueryError.invalidEndpoint("\(label)不是完整 URL")
        }
        guard url.user == nil, url.password == nil else {
            throw VoiceQueryError.invalidEndpoint("不要把账号或密钥写入 \(label) URL")
        }

        if scheme == secureScheme {
            return url
        }
        if scheme == localScheme && isLoopback(host) {
            return url
        }

        throw VoiceQueryError.invalidEndpoint(
            "\(label)必须使用 \(secureScheme)；仅 localhost 可使用 \(localScheme)"
        )
    }

    private static func isLoopback(_ host: String) -> Bool {
        host == "localhost" || host == "127.0.0.1" || host == "::1"
    }
}
