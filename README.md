# VoiceQuery 延迟验证原型

VoiceQuery 是一个 macOS 菜单栏原型。用户按住 `⌥Space` 说话，应用通过 OpenAI Realtime API 边说边转写，再通过 Responses API 整理成适合 AI 阅读的 Query。

## 当前范围

- 全局按住说话快捷键：`⌥Space`
- `gpt-live-transcribe` 实时增量转写
- 轻度整理和结构化 Query 两种模式
- 3 秒总体超时与原始转写降级
- 数字、URL、路径、代码、ID 和否定词校验
- 目标输入框捕获、密码框保护和辅助功能写入
- API Key 仅存储在 macOS Keychain
- 可配置 Responses API URL、Realtime WebSocket URL 和两类模型名
- 菜单栏内显示转写、整理和总体延迟

## 构建

要求：macOS 14 或更高版本、Swift 5.10 或更高版本。完整 Xcode 不是编译此 Swift Package 的必要条件。

```bash
swift run VoiceQueryChecks
./scripts/build-app.sh
open dist/VoiceQuery.app
```

首次运行后：

1. 打开菜单栏中的 VoiceQuery。
2. 在“设置”中填写个人 OpenAI API Key，并保存。
3. 请求辅助功能权限。
4. 把光标放入目标输入框。
5. 按住 `⌥Space` 说话，松开后等待整理结果。

麦克风权限会在第一次录音时由 macOS 请求。

## 第三方中转站

设置页允许修改：

- 整理接口 URL，例如 `https://relay.example.com/v1/responses`
- 整理模型
- Realtime WebSocket URL，例如 `wss://relay.example.com/v1/realtime`
- 实时转写模型

当前兼容前提：

1. 整理服务兼容 OpenAI Responses API，并支持 `text.format` Structured Outputs。
2. 实时转写服务兼容 OpenAI Realtime WebSocket 协议、`session.update`、`input_audio_buffer.append` 和转写增量事件。
3. 两条链路都接受 `Authorization: Bearer <API Key>`。

只兼容 `/v1/chat/completions` 或普通 `/v1/audio/transcriptions` 的中转站不能直接使用当前低延迟链路。远程接口必须使用 `https` 和 `wss`；只有 `localhost` 可以使用 `http` 或 `ws`。

## 安全边界

- 本原型是个人 BYOK（Bring Your Own Key）工具，不应内置或分发共享的服务端 API Key。
- 当前同一个 API Key 会发送给设置的整理接口和 Realtime 接口。不要把 OpenAI Key 填给不受信任的中转站。
- 第三方中转站会收到原始音频和转写文本；其保存与使用规则由第三方决定。
- 本原型只上传按键期间的音频和对应转写，不读取屏幕、剪贴板、历史对话或输入框已有内容。
- `store: false` 会随 Responses API 整理请求发送。
- 输入框不支持辅助功能直接写入时，应用退回到剪贴板粘贴。此时整理结果会留在系统剪贴板中。
- 如果要面向其他用户分发，应增加自己的后端，并为客户端提供短期凭据；不要把开发者 API Key 放进应用。

## 延迟验收

设计目标：

- 松开快捷键到最终转写：通常不超过 800 ms。
- Query 整理：通常不超过 1,000 ms。
- 松开快捷键到结果就绪：中位数不超过 1.5 秒，95% 不超过 3 秒。
- 超过 3 秒时停止等待，并保留已经收到的实时转写。

这些数字是验收目标，不是当前环境的实测结果。Structured Outputs 首次使用新 Schema 时可能存在额外处理延迟，因此冷启动和热请求必须分开统计。

## 尚未验证

- 当前工作区没有配置 OpenAI API Key，因此没有进行真实云端调用。
- 当前机器只有 Command Line Tools，没有完整 Xcode；检查程序不依赖 `XCTest`。
- 辅助功能写入需要在实际目标应用中验证。不同 Electron、浏览器和原生输入框的支持情况可能不同。
