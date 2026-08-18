@preconcurrency import AVFoundation
import Foundation

public final class AudioCaptureService: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var converter: AVAudioConverter?
    private var running = false

    public init() {}

    public func start(onChunk: @escaping @Sendable (Data) -> Void) async throws {
        guard await requestMicrophonePermission() else {
            throw VoiceQueryError.microphonePermissionDenied
        }

        try startEngine(onChunk: onChunk)
    }

    private func startEngine(onChunk: @escaping @Sendable (Data) -> Void) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !running else {
            return
        }

        let inputNode = engine.inputNode
        let sourceFormat = inputNode.outputFormat(forBus: 0)
        guard sourceFormat.sampleRate > 0,
              let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: 24_000,
                channels: 1,
                interleaved: true
              ),
              let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw VoiceQueryError.invalidAudioFormat
        }

        self.converter = converter
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1_024,
            format: sourceFormat
        ) { [weak self] buffer, _ in
            guard let self,
                  let data = self.convert(
                    buffer,
                    converter: converter,
                    targetFormat: targetFormat
                  ),
                  !data.isEmpty else {
                return
            }
            onChunk(data)
        }

        engine.prepare()
        do {
            try engine.start()
            running = true
        } catch {
            inputNode.removeTap(onBus: 0)
            self.converter = nil
            throw error
        }
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard running else {
            return
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        running = false
    }

    private func requestMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    private func convert(
        _ input: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) -> Data? {
        let ratio = targetFormat.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * ratio)) + 8
        guard let output = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: capacity
        ) else {
            return nil
        }

        var suppliedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, statusPointer in
            if suppliedInput {
                statusPointer.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            statusPointer.pointee = .haveData
            return input
        }

        guard conversionError == nil,
              status != .error,
              output.frameLength > 0,
              let channelData = output.int16ChannelData else {
            return nil
        }

        let byteCount = Int(output.frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: channelData[0], count: byteCount)
    }
}
