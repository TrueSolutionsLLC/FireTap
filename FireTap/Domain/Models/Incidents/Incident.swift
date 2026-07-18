import Foundation

/// A surfaced operational incident derived from real signals (function status,
/// log severity, or audit trail entries). Severity is never invented — it is
/// copied or mapped 1:1 from the input signal.
struct Incident: Sendable, Identifiable, Equatable, Hashable {
    let id: UUID
    /// Raw severity string taken from the source signal (e.g. log `ERROR`,
    /// function `FAILED`, or `AUDIT` for audit-trail observations).
    let severity: String
    let title: String
    let detail: String
    let sourceModule: String
    let resource: String
    let timestamp: Date
    var acknowledged: Bool

    init(
        id: UUID = UUID(),
        severity: String,
        title: String,
        detail: String,
        sourceModule: String,
        resource: String,
        timestamp: Date,
        acknowledged: Bool = false
    ) {
        self.id = id
        self.severity = severity
        self.title = title
        self.detail = detail
        self.sourceModule = sourceModule
        self.resource = resource
        self.timestamp = timestamp
        self.acknowledged = acknowledged
    }
}

/// Pure aggregator: builds incidents only from provided signals. Does not
/// upgrade or invent severity beyond mapping known input fields.
enum IncidentAggregator {
    /// Function statuses that already indicate an error/failure signal.
    private static let functionErrorStatuses: Set<String> = [
        "FAILED",
        "UNKNOWN",
        "OFFLINE",
        "CLOUD_FUNCTION_STATUS_UNSPECIFIED",
        "DEPLOY_FAILED",
        "DELETE_FAILED",
        "STATE_UNSPECIFIED"
    ]

    /// Log severities treated as incident-worthy (exact GCP Logging names).
    private static let incidentLogSeverities: Set<String> = [
        "ERROR",
        "CRITICAL",
        "ALERT",
        "EMERGENCY"
    ]

    static func aggregate(
        functionErrors: [CloudFunctionSummary],
        logEntries: [LogEntry],
        auditEntries: [AuditEntry]
    ) -> [Incident] {
        var incidents: [Incident] = []

        for function in functionErrors {
            guard let status = function.status?.uppercased(),
                  functionErrorStatuses.contains(status) else {
                continue
            }
            incidents.append(
                Incident(
                    severity: status,
                    title: "Function \(function.displayName) — \(status)",
                    detail: [
                        function.runtime.map { "runtime: \($0)" },
                        function.trigger.map { "trigger: \($0)" },
                        function.region.map { "region: \($0)" }
                    ].compactMap { $0 }.joined(separator: " · "),
                    sourceModule: "functions",
                    resource: function.name,
                    timestamp: parseTimestamp(function.updateTime) ?? .now
                )
            )
        }

        for entry in logEntries {
            guard let severity = entry.severity?.uppercased(),
                  incidentLogSeverities.contains(severity) else {
                continue
            }
            let resourceName = entry.resource?.labels?["function_name"]
                ?? entry.resource?.type
                ?? entry.trace
                ?? "log"
            let detail = entry.textPayload
                ?? entry.jsonPayload.flatMap { String(data: $0, encoding: .utf8) }
                ?? ""
            incidents.append(
                Incident(
                    severity: severity,
                    title: "Log \(severity)",
                    detail: detail,
                    sourceModule: "logs",
                    resource: resourceName,
                    timestamp: parseTimestamp(entry.timestamp) ?? .now
                )
            )
        }

        for audit in auditEntries {
            // Audit entries carry no GCP severity. Surface them as AUDIT so the
            // UI never confuses an audit observation with a health severity.
            incidents.append(
                Incident(
                    severity: "AUDIT",
                    title: audit.action,
                    detail: audit.summary,
                    sourceModule: "audit",
                    resource: audit.resource,
                    timestamp: audit.timestamp
                )
            )
        }

        return incidents.sorted { $0.timestamp > $1.timestamp }
    }

    private static func parseTimestamp(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: value)
    }
}
