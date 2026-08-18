import AppKit
import SwiftUI
import VoiceQueryCore

struct MenuContent: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: model.state.isRecording ? "mic.fill" : "waveform")
                    .foregroundStyle(model.state.isRecording ? Color.red : Color.accentColor)
                Text("SayQuery")
                    .font(.headline)
                Spacer()
                Text("⌥Space")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Text(model.statusText)
                .font(.callout)
                .foregroundStyle(model.state == .failed ? .red : .primary)

            if !model.partialTranscript.isEmpty && model.state != .ready {
                GroupBox("实时转写") {
                    Text(model.partialTranscript)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(5)
                        .textSelection(.enabled)
                }
            }

            if !model.lastQuery.isEmpty {
                GroupBox("整理结果") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.lastQuery)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(8)
                            .textSelection(.enabled)

                        if !model.lastAmbiguities.isEmpty {
                            Text("待确认：\(model.lastAmbiguities.joined(separator: "；"))")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        HStack {
                            Button("写入原输入框") {
                                model.insertLastQuery()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("复制") {
                                model.copyLastQuery()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            Picker("整理模式", selection: $settings.mode) {
                ForEach(QueryMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if let total = model.latency.releaseToReadyMilliseconds {
                HStack(spacing: 10) {
                    metric("转写", model.latency.releaseToTranscriptMilliseconds)
                    metric("整理", model.latency.normalizationMilliseconds)
                    metric("总计", total)
                }
            }

            Divider()

            HStack {
                SettingsLink {
                    Label("设置", systemImage: "gearshape")
                }
                Spacer()
                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 390)
    }

    private func metric(_ label: String, _ milliseconds: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(milliseconds.map { String(format: "%.0f ms", $0) } ?? "—")
                .font(.caption.monospacedDigit())
        }
    }
}
