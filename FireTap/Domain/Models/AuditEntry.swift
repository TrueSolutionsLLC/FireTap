import Foundation

/// A single record in the local, encrypted audit trail. Contains only
/// non-sensitive descriptors — never tokens, full document bodies, or secrets.
struct AuditEntry: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let accountID: String?
    let projectID: String
    let action: String
    let resource: String
    let summary: String
    /// Whether this action can be truly reversed. Never set true unless a real
    /// inverse operation exists.
    let reversible: Bool
    /// Short before/after descriptors for reversible actions (already redacted).
    let beforeValue: String?
    let afterValue: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        accountID: String?,
        projectID: String,
        action: String,
        resource: String,
        summary: String,
        reversible: Bool = false,
        beforeValue: String? = nil,
        afterValue: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.accountID = accountID
        self.projectID = projectID
        self.action = action
        self.resource = resource
        self.summary = summary
        self.reversible = reversible
        self.beforeValue = beforeValue
        self.afterValue = afterValue
    }
}
