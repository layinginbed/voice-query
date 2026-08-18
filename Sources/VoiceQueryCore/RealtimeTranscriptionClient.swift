import Foundation

public enum TranscriptionEvent: Sendable, Equatable {
    case delta(String)
    case completed(String)
    case serverError(String)
}

public actor RealtimeTranscriptionClient {
    private let session: URLSession
    private var socket: URLSessionWebSocketTask?
    private var receiverTask: Task<Void, Never>?
    private var continuation: AsyncThrowingStream<TranscriptionEvent, Error>.Continuation?
    private var configured = false
    private var pendingAudio: [Data] = []
    private var pendingCommit = false

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func connect(
        apiKey: String,
        endpoint: URL,
        model: String,
        delay: String = "low"
    ) async throws -> AsyncThrowingStream<TranscriptionEvent, Error> {
        receiverTask?.cancel()
        receiverTask = nil
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        continuation?.finish()
        continuation = nil
        configured = false

        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw VoiceQueryError.invalidResponse
        }
        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "model" }
        queryItems.append(URLQueryItem(name: "model", value: model))
        components.queryItems = queryItems
        guard let url = components.url else {
            throw VoiceQueryError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let socket = session.webSocketTask(with: request)
        self.socket = socket

        let pair = AsyncThrowingStream<TranscriptionEvent, Error>.makeStream()
        continuation = pair.continuation

        socket.resume()
        receiverTask = Task { [weak self] in
            await self?.receiveLoop(socket: socket)
        }

        try await sendSessionConfiguration(model: model, delay: delay)
        configured = true
        try await flushPendingAudio()

        return pair.stream
    }

    public func appendAudio(_ pcm16Data: Data) async throws {
        guard !pcm16Data.isEmpty else {
            return
        }

        guard configured else {
            pendingAudio.append(pcm16Data)
            return
        }

        try await sendJSON([
            "type": "input_audio_buffer.append",
            "audio": pcm16Data.base64EncodedString()
        ])
    }

    public func commit() async throws {
        guard configured else {
            pendingCommit = true
            return
        }
        try await sendJSON(["type": "input_audio_buffer.commit"])
    }

    public func disconnect() {
        receiverTask?.cancel()
        receiverTask = nil
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        continuation?.finish()
        continuation = nil
        configured = false
        pendingAudio.removeAll(keepingCapacity: false)
        pendingCommit = false
    }

    private func sendSessionConfiguration(model: String, delay: String) async throws {
        try await sendJSON([
            "type": "session.update",
            "session": [
                "type": "transcription",
                "audio": [
                    "input": [
                        "format": [
                            "type": "audio/pcm",
                            "rate": 24_000
                        ],
                        "transcription": [
                            "model": model,
                            "languages": ["zh-cn", "en"],
                            "delay": delay
                        ],
                        "turn_detection": NSNull()
                    ]
                ]
            ]
        ])
    }

    private func flushPendingAudio() async throws {
        let buffered = pendingAudio
        pendingAudio.removeAll(keepingCapacity: true)
        for chunk in buffered {
            try await appendAudio(chunk)
        }
        if pendingCommit {
            pendingCommit = false
            try await commit()
        }
    }

    private func sendJSON(_ object: [String: Any]) async throws {
        guard let socket else {
            throw VoiceQueryError.websocketNotConnected
        }
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else {
            throw VoiceQueryError.invalidResponse
        }
        try await socket.send(.string(text))
    }

    private func receiveLoop(socket: URLSessionWebSocketTask) async {
        do {
            while !Task.isCancelled {
                let message = try await socket.receive()
                let data: Data
                switch message {
                case .string(let text):
                    data = Data(text.utf8)
                case .data(let rawData):
                    data = rawData
                @unknown default:
                    continue
                }

                guard let event = try? JSONDecoder().decode(RealtimeEnvelope.self, from: data) else {
                    continue
                }

                switch event.type {
                case "conversation.item.input_audio_transcription.delta":
                    if let delta = event.delta, !delta.isEmpty {
                        continuation?.yield(.delta(delta))
                    }
                case "conversation.item.input_audio_transcription.completed":
                    continuation?.yield(.completed(event.transcript ?? ""))
                case "error":
                    let message = event.error?.message ?? "未知 Realtime 错误"
                    continuation?.yield(.serverError(message))
                default:
                    continue
                }
            }
        } catch is CancellationError {
            continuation?.finish()
        } catch {
            continuation?.finish(throwing: error)
        }
    }
}

private struct RealtimeEnvelope: Decodable {
    struct RealtimeError: Decodable {
        let message: String?
    }

    let type: String
    let delta: String?
    let transcript: String?
    let error: RealtimeError?
}
