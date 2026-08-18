<p align="center">
  <img src="docs/assets/sayquery-mark.svg" width="112" alt="SayQuery logo">
</p>

<h1 align="center">SayQuery</h1>

<p align="center"><strong>说话像平时一样，输入像认真写过一样。</strong></p>

<p align="center">
  在 Mac 上按住 <code>⌥Space</code> 说话，SayQuery 会把口语整理成清晰的 AI Query，并送回你正在使用的输入框。
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-111111?logo=apple">
  <img alt="Status Alpha" src="https://img.shields.io/badge/status-alpha-F59E0B">
  <img alt="Bring Your Own Key" src="https://img.shields.io/badge/API%20key-BYOK-6366F1">
</p>

---

## SayQuery 能为你做什么

语音输入很快，但说出来的话经常带有停顿、重复和临时补充。直接发给 AI，容易让真正的任务和限制条件淹没在口语里。

SayQuery 会在发送前帮你完成一次保守整理：删除无意义重复，理顺表达顺序，保留数字、代码、路径和否定条件。它只整理你的意思，不替你回答问题，也不会擅自添加要求。

### 一个例子

你说：

> 帮我看一下这个登录失败的问题，就是昨天升级以后开始的。先不要改代码，你先告诉我可能是什么原因，然后给我一个排查顺序。对了，错误码是 401，不是 403。

SayQuery 可以整理为：

```text
目标：分析升级后出现的登录失败问题。

已知信息：
- 问题从昨天升级后开始。
- 错误码是 401，不是 403。

任务：
1. 说明可能原因。
2. 给出建议的排查顺序。

约束：先不要修改代码。
```

实际结果会根据你的原话和所选整理模式变化。

## 四步开始使用

1. 把光标放在你准备输入文字的位置。
2. 按住 `⌥Space`。
3. 像平时说话一样表达需求。
4. 松开快捷键，确认整理结果后写入输入框。

你可以在设置中打开“校验通过后自动写入”。关闭时，结果会留在 SayQuery 菜单栏窗口中，供你确认、复制或手动写入。

> [!TIP]
> 说话时不需要刻意组织成模板。先讲清目标，再补充背景和限制即可；SayQuery 会在不改变原意的前提下整理顺序。

## 两种整理模式

| 模式 | 适合场景 | SayQuery 会做什么 |
|---|---|---|
| **轻度整理** | 聊天、邮件、搜索等短输入 | 修正断句和标点，删除口头禅与无意义重复，不套用模板 |
| **Query 整理** | 给 ChatGPT、Claude、Codex 等 AI 提交任务 | 按实际内容整理目标、背景、任务、约束和期望输出；空栏目不会生成 |

SayQuery 会尽量原样保留代码、命令、URL、文件路径、ID、数字和否定表达。如果内容存在无法安全消除的歧义，它会保留结果供你预览，不自动写入。

## 安装

SayQuery 目前处于 Alpha 阶段，暂未提供签名和公证后的安装包。当前版本需要从源码构建。

### 你需要准备

- macOS 14 或更高版本
- Swift 5.10 或更高版本
- 一个可用的 OpenAI API Key，或兼容中转站提供的 API Key

### 从源码启动

```bash
git clone https://github.com/layinginbed/sayquery.git
cd sayquery
./scripts/build-app.sh
open dist/SayQuery.app
```

第一次使用时：

1. 点击菜单栏中的 SayQuery 图标。
2. 打开“设置”，填写 API Key，然后保存。
3. 按系统提示允许 SayQuery 使用麦克风。
4. 在“系统设置 → 隐私与安全性 → 辅助功能”中允许 SayQuery 控制电脑。

API Key 只保存在当前 Mac 的 Keychain 中，不会写入项目文件。

## 可以在哪些地方使用

SayQuery 的目标是写入当前聚焦的 macOS 输入框，包括浏览器、原生应用和部分 Electron 应用。

不同应用对 macOS 辅助功能的支持并不完全一致：

- 可以直接访问的普通输入框：SayQuery 直接写入。
- 无法直接访问的输入框：SayQuery 会尝试通过剪贴板粘贴。
- 密码框等安全输入框：SayQuery 不会写入。
- 没有找到输入框：结果仍会保留在菜单栏窗口中。

当前还没有完成 Safari、Chrome、Electron 和各类原生应用的完整兼容性测试。如果某个输入框无法使用，请在 [Issues](https://github.com/layinginbed/sayquery/issues) 中提交应用名称和 macOS 版本。

## 使用 OpenAI 或第三方中转站

### 直接使用 OpenAI

在设置中填写个人 OpenAI API Key，保留默认接口地址和模型即可。SayQuery 会分别调用实时转写服务和 Query 整理服务。

### 使用第三方中转站

你可以在设置中修改整理接口、Realtime WebSocket 接口及对应模型名称。中转站必须同时兼容 SayQuery 使用的两条链路；只提供普通聊天接口的中转站不能直接使用。

<details>
<summary><strong>查看中转站兼容要求</strong></summary>

整理链路必须兼容：

- OpenAI Responses API
- `text.format` Structured Outputs
- `Authorization: Bearer &lt;API Key&gt;`

实时转写链路必须兼容：

- OpenAI Realtime WebSocket 协议
- `session.update`
- `input_audio_buffer.append`
- 实时转写增量事件
- `Authorization: Bearer &lt;API Key&gt;`

仅支持 `/v1/chat/completions` 或普通 `/v1/audio/transcriptions` 的中转站不能直接接入当前低延迟流程。远程接口必须使用 `https` 和 `wss`；只有 `localhost` 可以使用 `http` 或 `ws`。

</details>

> [!WARNING]
> 当前同一个 API Key 会发送给你配置的整理接口和 Realtime 接口。不要把 OpenAI API Key 填入不受信任的中转站。

## 隐私说明

- SayQuery 只录制你按住快捷键期间的声音。
- 音频会发送给你配置的实时转写服务。
- 转写文本会发送给你配置的 Query 整理服务。
- SayQuery 不读取屏幕、历史对话或输入框中的既有内容。
- Query 整理请求会携带 `store: false`。
- 使用剪贴板粘贴时，整理结果会留在系统剪贴板中。
- API Key 仅保存在 macOS Keychain。

第三方服务如何保存和使用音频、转写及日志，由对应服务的隐私政策决定。

## 常见问题

<details>
<summary><strong>按住 ⌥Space 后没有反应</strong></summary>

确认 SayQuery 正在菜单栏运行，并检查麦克风权限。如果其他应用占用了同一个全局快捷键，也可能导致 SayQuery 无法收到按键事件。

</details>

<details>
<summary><strong>已经生成结果，但没有写入输入框</strong></summary>

确认目标输入框仍处于聚焦状态，并检查 SayQuery 的辅助功能权限。如果关闭了“校验通过后自动写入”，请在菜单栏窗口中点击“写入原输入框”。存在歧义或关键信息校验失败时，SayQuery 也会要求你先预览。

</details>

<details>
<summary><strong>云端服务返回错误</strong></summary>

检查 API Key、接口地址和模型名称。使用中转站时，还需要确认整理接口与 Realtime 接口分别满足上面的兼容要求。

</details>

<details>
<summary><strong>等待时间太长</strong></summary>

SayQuery 采用流式转写，并把松开快捷键后的总体等待限制在约 3 秒。超过限制时，它会停止等待整理结果，并尽量保留已经收到的原始转写。实际速度仍取决于网络、中转站和模型响应时间。

</details>

## 当前版本的边界

- 项目处于 Alpha 阶段，尚未提供可直接下载的正式 Release。
- 维护者当前只完成了本地构建和逻辑检查，尚未使用真实 API Key 完成公开记录的端到端云端验证。
- “松开后约 1.5 秒得到结果”是设计目标，不是已经证明的性能承诺。
- 不同应用输入框的兼容性仍在验证中。

如果你希望尝试当前版本，建议先关闭自动写入，确认整理结果符合预期后再打开。

<details>
<summary><strong>开发者信息</strong></summary>

### 本地检查

```bash
swift run SayQueryChecks
swift build --product SayQuery
./scripts/build-app.sh
codesign --verify --deep --strict dist/SayQuery.app
plutil -lint dist/SayQuery.app/Contents/Info.plist
```

### 默认云端配置

| 用途 | 默认配置 |
|---|---|
| Query 整理接口 | `https://api.openai.com/v1/responses` |
| Query 整理模型 | `gpt-5.6` |
| 实时转写接口 | `wss://api.openai.com/v1/realtime` |
| 实时转写模型 | `gpt-live-transcribe` |

### 延迟设计目标

| 阶段 | 目标 |
|---|---:|
| 松开快捷键到最终转写 | 通常不超过 800 ms |
| Query 整理 | 通常不超过 1,000 ms |
| 松开快捷键到结果就绪 | 中位数不超过 1.5 s，P95 不超过 3 s |
| 超时降级 | 3 s 后停止等待并保留实时转写 |

这些数字是验收目标，不是当前环境的实测结果。Structured Outputs 首次使用新 Schema 时可能产生额外延迟，因此冷启动和热请求应分开统计。

</details>

---

如果 SayQuery 帮你减少了重复修改 Prompt 的时间，欢迎点一个 Star。遇到问题或有建议，请提交 [Issue](https://github.com/layinginbed/sayquery/issues)。
