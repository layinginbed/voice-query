import AppKit
import Combine
import Foundation
import VoiceQueryCore

@MainActor
final class AppModel: ObservableObject {
    enum State: Equatable {
        case idle
        case connecting
        case listening
        case finalizing
        case ready
        case failed

        var isRecording: Bool {
            self == .connecting || self == .listening
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var statusText = "按住 ⌥Space 开始说话"
    @Published private(set) var partialTranscript = ""
    @Published private(set) var lastRawTranscript = ""
    @Published private(set) var lastQuery = ""
    @Published private(set) var lastAmbiguities: [String] = []
    @Published private(set) var latency = LatencySnapshot()

    let settings: SettingsStore

    private let audioCapture = AudioCaptureService()
    private let transcriber = RealtimeTranscriptionClient()
    private let normalizer = OpenAIQueryNormalizer()

    private var eventTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var activeSessionID: UUID?
    private var releaseRequested = false
    private var releaseDate: Date?
    private var finishedSession = false
    private var textTarget: TextTarget?
    private var activeCloudSettings: ValidatedCloudSettings?
    private var activeAPIKey = ""

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func beginPress() async {
        guard state == .idle || state == .ready || state == .failed else {
            return
        }

        let apiKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            state = .failed
            statusText = VoiceQueryError.missingAPIKey.localizedDescription
            return
        }
        let cloudSettings: ValidatedCloudSettings
        do {
            cloudSettings = try settings.validatedCloudSettings()
        } catch {
            state = .failed
            statusText = error.localizedDescription
            return
        }

        await cancelCurrentWork()
        let sessionID = UUID()
        activeSessionID = sessionID
        activeCloudSettings = cloudSettings
        activeAPIKey = apiKey
        releaseRequested = false
        finishedSession = false
        releaseDate = nil
        latency = LatencySnapshot()
        partialTranscript = ""
        lastRawTranscript = ""
        lastQuery = ""
        lastAmbiguities = []
        textTarget = try? TextInjector.captureTarget()
        state = .connecting
        statusText = "正在连接实时转写…"

        let client = transcriber
        do {
            try await audioCapture.start { data in
                Task {
                    try? await client.appendAudio(data)
                }
            }

            let stream = try await transcriber.connect(
                apiKey: apiKey,
                endpoint: cloudSettings.realtimeURL,
                model: cloudSettings.transcriptionModel,
                delay: settings.transcriptionDelay
            )

            guard activeSessionID == sessionID else {
                return
            }

            eventTask = Task { [weak self] in
                do {
                    for try await event in stream {
                        guard !Task.isCancelled else { return }
                        await self?.handle(event, sessionID: sessionID)
                    }
                } catch {
                    await self?.handleStreamFailure(error, sessionID: sessionID)
                }
            }

            if releaseRequested {
                state = .finalizing
                statusText = "正在完成转写…"
            } else {
                state = .listening
                statusText = "正在听…松开 ⌥Space 完成"
            }
        } catch {
            audioCapture.stop()
            await transcriber.disconnect()
            guard activeSessionID == sessionID else { return }
            activeCloudSettings = nil
            activeAPIKey = ""
            state = .failed
            statusText = error.localizedDescription
        }
    }

    func endPress() async {
        guard state == .connecting || state == .listening else {
            return
        }

        releaseRequested = true
        releaseDate = Date()
        audioCapture.stop()
        state = .finalizing
        statusText = "正在完成转写…"
        scheduleOverallTimeout(for: activeSessionID)

        do {
            try await transcriber.commit()
        } catch {
            await fallbackAfterFailure(error, sessionID: activeSessionID)
        }
    }

    func insertLastQuery() {
        guard !lastQuery.isEmpty else {
            return
        }
        do {
            try TextInjector.insert(lastQuery, into: textTarget)
            statusText = "已写入原输入框"
        } catch {
            statusText = error.localizedDescription
        }
    }

    func copyLastQuery() {
        guard !lastQuery.isEmpty else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastQuery, forType: .string)
        statusText = "已复制整理结果"
    }

    func reset() async {
        await cancelCurrentWork()
        state = .idle
        statusText = "按住 ⌥Space 开始说话"
        partialTranscript = ""
    }

    private func handle(_ event: TranscriptionEvent, sessionID: UUID) async {
        guard activeSessionID == sessionID, !finishedSession else {
            return
        }

        switch event {
        case .delta(let text):
            partialTranscript += text
        case .completed(let transcript):
            let finalText = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            lastRawTranscript = finalText.isEmpty ? partialTranscript : finalText
            if let releaseDate {
                latency.releaseToTranscriptMilliseconds = milliseconds(since: releaseDate)
            }
            await normalizeAndFinish(sessionID: sessionID)
        case .serverError(let message):
            await fallbackAfterFailure(
                VoiceQueryError.server(message),
                sessionID: sessionID
            )
        }
    }

    private func normalizeAndFinish(sessionID: UUID) async {
        guard activeSessionID == sessionID,
              !finishedSession,
              let cloudSettings = activeCloudSettings,
              !lastRawTranscript.isEmpty else {
            await fallbackAfterFailure(
                VoiceQueryError.invalidResponse,
                sessionID: sessionID
            )
            return
        }

        state = .finalizing
        statusText = "正在整理 Query…"
        let normalizationStart = Date()

        do {
            let result = try await normalizer.normalize(
                transcript: lastRawTranscript,
                mode: settings.mode,
                apiKey: activeAPIKey,
                model: cloudSettings.normalizerModel,
                endpoint: cloudSettings.responsesURL,
                timeoutSeconds: 1.4
            )
            latency.normalizationMilliseconds = milliseconds(since: normalizationStart)
            await finish(result: result, sessionID: sessionID, usedFallback: false)
        } catch {
            latency.normalizationMilliseconds = milliseconds(since: normalizationStart)
            await fallbackAfterFailure(error, sessionID: sessionID)
        }
    }

    private func fallbackAfterFailure(_ error: Error, sessionID: UUID?) async {
        guard let sessionID,
              activeSessionID == sessionID,
              !finishedSession else {
            return
        }

        let fallbackSource = lastRawTranscript.isEmpty
            ? partialTranscript
            : lastRawTranscript
        let fallback = LocalLightCleaner.clean(fallbackSource)
        guard !fallback.isEmpty else {
            finishedSession = true
            state = .failed
            statusText = error.localizedDescription
            await transcriber.disconnect()
            activeCloudSettings = nil
            activeAPIKey = ""
            return
        }

        let result = NormalizationResult(
            query: fallback,
            ambiguities: [],
            preservedLiterals: LiteralGuard.extract(from: fallback),
            shouldPreview: false
        )
        await finish(result: result, sessionID: sessionID, usedFallback: true)
    }

    private func finish(
        result: NormalizationResult,
        sessionID: UUID,
        usedFallback: Bool
    ) async {
        guard activeSessionID == sessionID, !finishedSession else {
            return
        }

        let validation = LiteralGuard.validate(
            source: lastRawTranscript,
            normalized: result.query
        )
        let requiresPreview = result.shouldPreview
            || !result.ambiguities.isEmpty
            || !validation.isSafe

        finishedSession = true
        timeoutTask?.cancel()
        lastAmbiguities = result.ambiguities
        lastQuery = validation.isSafe
            ? result.query
            : LocalLightCleaner.clean(lastRawTranscript)
        if let releaseDate {
            latency.releaseToReadyMilliseconds = milliseconds(since: releaseDate)
        }

        state = .ready
        if usedFallback {
            statusText = "云端超时或失败，已保留实时转写"
        } else if requiresPreview {
            statusText = "检测到歧义或字面量变化，请先预览"
        } else {
            statusText = "整理完成"
        }

        if settings.autoInsert && !requiresPreview {
            insertLastQuery()
        }

        await transcriber.disconnect()
        activeCloudSettings = nil
        activeAPIKey = ""
    }

    private func scheduleOverallTimeout(for sessionID: UUID?) {
        timeoutTask?.cancel()
        guard let sessionID else { return }
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.fallbackAfterFailure(
                VoiceQueryError.requestTimedOut,
                sessionID: sessionID
            )
        }
    }

    private func handleStreamFailure(_ error: Error, sessionID: UUID) async {
        await fallbackAfterFailure(error, sessionID: sessionID)
    }

    private func cancelCurrentWork() async {
        eventTask?.cancel()
        eventTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        audioCapture.stop()
        await transcriber.disconnect()
        activeSessionID = nil
        activeCloudSettings = nil
        activeAPIKey = ""
        textTarget = nil
    }

    private func milliseconds(since date: Date) -> Double {
        Date().timeIntervalSince(date) * 1_000
    }
}
