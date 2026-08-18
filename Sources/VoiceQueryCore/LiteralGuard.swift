import Foundation

public enum LocalLightCleaner {
    public static func clean(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"[\t ]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum LiteralGuard {
    private static let patterns = [
        #"```[\s\S]*?```"#,
        #"`[^`\n]+`"#,
        #"https?://[^\s，。！？；]+"#,
        #"(?:~?/|\./|\.\./)[^\s，。！？；]+"#,
        #"\b[A-Z][A-Z0-9_]*-\d+\b"#,
        #"(?<![\p{L}\p{N}_])[+-]?\d+(?:[.,]\d+)?(?:%|ms|s|秒|分钟|小时|KB|MB|GB|TB)?(?![\p{L}\p{N}_])"#
    ]

    private static let negations = [
        "不要", "不能", "不需要", "不允许", "先别", "不要修改", "不要删除", "无需", "禁止"
    ]

    public static func extract(from text: String) -> [String] {
        var acceptedMatches: [(range: NSRange, value: String)] = []
        var seen = Set<String>()
        var occupiedRanges: [NSRange] = []

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, range: range) {
                guard !occupiedRanges.contains(where: {
                    NSIntersectionRange($0, match.range).length > 0
                }) else {
                    continue
                }
                guard let swiftRange = Range(match.range, in: text) else {
                    continue
                }
                let value = String(text[swiftRange])
                if seen.insert(value).inserted {
                    acceptedMatches.append((match.range, value))
                    occupiedRanges.append(match.range)
                }
            }
        }

        return acceptedMatches
            .sorted { $0.range.location < $1.range.location }
            .map(\.value)
    }

    public static func validate(source: String, normalized: String) -> LiteralValidation {
        let literals = extract(from: source)
        let missingLiterals = literals.filter { !normalized.contains($0) }
        let sourceNegations = negations.filter { source.contains($0) }
        let missingNegations = sourceNegations.filter { !normalized.contains($0) }

        return LiteralValidation(
            sourceLiterals: literals,
            missingLiterals: missingLiterals,
            missingNegations: missingNegations
        )
    }
}
