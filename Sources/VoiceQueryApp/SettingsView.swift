import SwiftUI
import VoiceQueryCore

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section("云端服务") {
                SecureField("API Key", text: $settings.apiKey)
                    .textFieldStyle(.roundedBorder)

                TextField("整理接口 URL", text: $settings.responsesEndpoint)
                    .textFieldStyle(.roundedBorder)

                TextField("整理模型", text: $settings.model)
                    .textFieldStyle(.roundedBorder)

                TextField("Realtime WebSocket URL", text: $settings.realtimeEndpoint)
                    .textFieldStyle(.roundedBorder)

                TextField("实时转写模型", text: $settings.transcriptionModel)
                    .textFieldStyle(.roundedBorder)

                Picker("实时转写延迟", selection: $settings.transcriptionDelay) {
                    Text("Minimal").tag("minimal")
                    Text("Low").tag("low")
                    Text("Medium").tag("medium")
                }

                Button("恢复 OpenAI 默认接口") {
                    settings.restoreOpenAIDefaults()
                }

                Text("中转站必须支持 Responses API 的 Structured Outputs，以及 OpenAI Realtime WebSocket 转写协议。只支持 /chat/completions 的中转站不能完整兼容。第三方服务会收到录音和转写文本。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("交互") {
                Picker("整理模式", selection: $settings.mode) {
                    ForEach(QueryMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Toggle("校验通过后自动写入", isOn: $settings.autoInsert)

                Text("关闭自动写入时，结果会保留在菜单栏窗口中。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("系统权限") {
                Button("请求辅助功能权限") {
                    _ = TextInjector.requestAccessibilityPermission()
                }
                Text("麦克风权限会在第一次按住 ⌥Space 时请求。密码框中始终禁用写入。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("保存设置") {
                    settings.save()
                }
                .buttonStyle(.borderedProminent)

                Text(settings.saveMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520)
    }
}
