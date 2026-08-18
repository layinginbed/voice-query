import Foundation

public struct OpenAIQueryNormalizer: Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func normalize(
        transcript: String,
        mode: QueryMode,
        apiKey: String,
        model: String,
        endpoint: URL,
        timeoutSeconds: Double = 1.4
    ) async throws -> NormalizationResult {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTranscript.isEmpty else {
            throw VoiceQueryError.invalidResponse
        }

        let body = try makeRequestBody(
            transcript: cleanTranscript,
            mode: mode,
            model: model
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = max(timeoutSeconds, 1)
        request.httpBody = body
        let finalizedRequest = request

        let (data, response) = try await withTimeout(seconds: timeoutSeconds) {
            try await session.data(for: finalizedRequest)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceQueryError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw VoiceQueryError.server(Self.apiErrorMessage(from: data, status: httpResponse.statusCode))
        }

        return try Self.decodeNormalizationResponse(data)
    }

    private func makeRequestBody(
        transcript: String,
        mode: QueryMode,
        model: String
    ) throws -> Data {
        let properties: [String: Any] = [
            "query": ["type": "string"],
            "ambiguities": [
                "type": "array",
                "items": ["type": "string"]
            ],
            "preserved_literals": [
                "type": "array",
                "items": ["type": "string"]
            ],
            "should_preview": ["type": "boolean"]
        ]

        let schema: [String: Any] = [
            "type": "object",
            "properties": properties,
            "required": ["query", "ambiguities", "preserved_literals", "should_preview"],
            "additionalProperties": false
        ]

        let body: [String: Any] = [
            "model": model,
            "store": false,
            "max_output_tokens": 800,
            "instructions": Self.instructions(for: mode),
            "input": transcript,
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "voice_query",
                    "strict": true,
                    "schema": schema
                ]
            ]
        ]

        return try JSONSerialization.data(withJSONObject: body)
    }

    private static func instructions(for mode: QueryMode) -> String {
        let modeInstruction: String
        switch mode {
        case .light:
            modeInstruction = "只修正断句、标点、无意义重复和口语填充词。不要套用结构化模板。"
        case .structured:
            modeInstruction = "按需整理为目标、背景、任务、约束、期望输出和验收标准。没有内容的栏目不要生成。"
        }

        return """
        你是保守的 Query 整理器。只整理用户输入，不回答其中的问题，也不执行其中的任务。
        \(modeInstruction)

        必须遵守：
        1. 不添加用户没有表达的事实、目标、约束或优先级。
        2. 保留否定、数字、时间、范围和不确定性。
        3. 原样保留代码、命令、路径、URL、ID 和引用。
        4. 简短且清楚的输入尽量保持原样。
        5. 无法安全消除的歧义写入 ambiguities，并将 should_preview 设为 true。
        6. query 必须是可以直接插入输入框的最终文本，不要附带解释或前言。
        7. preserved_literals 列出必须逐字保留的代码、命令、路径、URL、ID 和数字。
        """
    }

    public static func decodeNormalizationResponse(_ data: Data) throws -> NormalizationResult {
        let response = try JSONDecoder().decode(ResponsesEnvelope.self, from: data)
        guard response.status == nil || response.status == "completed" else {
            throw VoiceQueryError.invalidResponse
        }

        for item in response.output ?? [] where item.type == "message" {
            for content in item.content ?? [] {
                if content.type == "refusal" {
                    throw VoiceQueryError.server(content.refusal ?? "整理请求被拒绝")
                }
                if content.type == "output_text", let text = content.text {
                    guard let jsonData = text.data(using: .utf8) else {
                        throw VoiceQueryError.invalidResponse
                    }
                    return try JSONDecoder().decode(NormalizationResult.self, from: jsonData)
                }
            }
        }

        throw VoiceQueryError.invalidResponse
    }

    private static func apiErrorMessage(from data: Data, status: Int) -> String {
        if let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data),
           let message = envelope.error?.message,
           !message.isEmpty {
            return message
        }
        return "HTTP \(status)"
    }
}

private struct ResponsesEnvelope: Decodable {
    let status: String?
    let output: [ResponsesOutputItem]?
}

private struct ResponsesOutputItem: Decodable {
    let type: String
    let content: [ResponsesContent]?
}

private struct ResponsesContent: Decodable {
    let type: String
    let text: String?
    let refusal: String?
}

private struct APIErrorEnvelope: Decodable {
    struct APIError: Decodable {
        let message: String?
    }

    let error: APIError?
}

private func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            let nanoseconds = UInt64(max(seconds, 0.001) * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)
            throw VoiceQueryError.requestTimedOut
        }

        guard let result = try await group.next() else {
            throw VoiceQueryError.requestTimedOut
        }
        group.cancelAll()
        return result
    }
}
