import Foundation

/// Groups log entries by a stable key for the logs browser.
struct LogEntryGroup: Identifiable, Sendable, Equatable {
    let key: String
    let entries: [LogEntry]

    var id: String { key }
    var count: Int { entries.count }
    var representative: LogEntry { entries[0] }

    static func group(_ entries: [LogEntry]) -> [LogEntryGroup] {
        var buckets: [String: [LogEntry]] = [:]
        var order: [String] = []
        for entry in entries {
            let key = groupKey(for: entry)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(entry)
        }
        return order.map { LogEntryGroup(key: $0, entries: buckets[$0] ?? []) }
    }

    static func groupKey(for entry: LogEntry) -> String {
        if let firstLine = entry.textPayload?
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init),
           !firstLine.isEmpty {
            return firstLine
        }
        let severity = entry.severity ?? "DEFAULT"
        let summary = entry.displaySummary
        let truncated = String(summary.prefix(80))
        return "\(severity)|\(truncated)"
    }
}

extension LogEntry {
    var displaySummary: String {
        if let textPayload, !textPayload.isEmpty { return textPayload }
        if let jsonPayloadText { return jsonPayloadText }
        return "(structured payload)"
    }

    var jsonPayloadText: String? {
        guard let jsonPayload else { return nil }
        if let object = try? JSONSerialization.jsonObject(with: jsonPayload),
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: pretty, encoding: .utf8) {
            return text
        }
        return String(data: jsonPayload, encoding: .utf8)
    }
}
