import Foundation
import VoiceQueryCore

private struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
        throw CheckFailure(description: message)
    }
}

private func runChecks() throws {
    let responsesURL = try EndpointValidator.responsesURL(
        from: "https://relay.example.com/v1/responses"
    )
    try expect(
        responsesURL.absoluteString == "https://relay.example.com/v1/responses",
        "HTTPS 整理接口应通过校验"
    )
    let realtimeURL = try EndpointValidator.realtimeURL(
        from: "wss://relay.example.com/v1/realtime"
    )
    try expect(
        realtimeURL.absoluteString == "wss://relay.example.com/v1/realtime",
        "WSS Realtime 接口应通过校验"
    )
    let localRealtimeURL = try EndpointValidator.realtimeURL(
        from: "ws://localhost:8787/v1/realtime"
    )
    try expect(
        localRealtimeURL.absoluteString == "ws://localhost:8787/v1/realtime",
        "localhost 应允许使用 WS"
    )
    do {
        _ = try EndpointValidator.responsesURL(
            from: "http://relay.example.com/v1/responses"
        )
        throw CheckFailure(description: "远程 HTTP 整理接口不应通过校验")
    } catch is VoiceQueryError {
        // Expected.
    }

    let source = "请检查 `/src/auth/login.swift` 和 https://example.com/a，超时设为 300ms，关联 ABC-42。"
    let extracted = LiteralGuard.extract(from: source)
    try expect(
        extracted == [
            "`/src/auth/login.swift`",
            "https://example.com/a",
            "300ms",
            "ABC-42"
        ],
        "受保护字面量提取结果不正确：\(extracted)"
    )

    let unsafe = LiteralGuard.validate(
        source: "不要修改 `/src/auth.swift`，超时保持 300ms。",
        normalized: "请检查认证代码。"
    )
    try expect(!unsafe.isSafe, "缺失字面量和否定词时必须判定为不安全")
    try expect(unsafe.missingLiterals.contains("300ms"), "必须检测缺失数字")
    try expect(unsafe.missingNegations.contains("不要"), "必须检测缺失否定词")

    let safe = LiteralGuard.validate(
        source: "先别删除 `/tmp/cache.json`，保留 20%。",
        normalized: "约束：先别删除 `/tmp/cache.json`，保留 20%。"
    )
    try expect(safe.isSafe, "完整保留字面量和否定词时应通过校验")

    try expect(
        LocalLightCleaner.clean("  不要   修改命令\n\n\n`git status`  ")
            == "不要 修改命令\n\n`git status`",
        "本地降级清理不应改变有效内容"
    )

    let structured = #"{"query":"目标：诊断登录问题。","ambiguities":[],"preserved_literals":["/src/auth"],"should_preview":false}"#
    let envelope: [String: Any] = [
        "status": "completed",
        "output": [
            [
                "type": "message",
                "content": [
                    ["type": "output_text", "text": structured]
                ]
            ]
        ]
    ]
    let data = try JSONSerialization.data(withJSONObject: envelope)
    let result = try OpenAIQueryNormalizer.decodeNormalizationResponse(data)
    try expect(result.query == "目标：诊断登录问题。", "Responses API 结果解析失败")
    try expect(result.preservedLiterals == ["/src/auth"], "受保护字段解析失败")
    try expect(!result.shouldPreview, "预览标记解析失败")
}

do {
    try runChecks()
    print("SayQueryChecks: all checks passed")
} catch {
    fputs("SayQueryChecks failed: \(error)\n", stderr)
    exit(1)
}
