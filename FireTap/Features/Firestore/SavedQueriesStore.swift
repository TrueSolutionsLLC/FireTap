import Foundation
import Observation

/// Local saved Firestore queries (non-sensitive). Never stores document contents.
@MainActor
@Observable
final class SavedQueriesStore {
    private let defaults: UserDefaults
    private let keyPrefix = "pc.savedQueries."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func queries(account: String, projectID: String) -> [SavedFirestoreQuery] {
        let key = keyPrefix + account + "." + projectID
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SavedFirestoreQuery].self, from: data)
        else { return [] }
        return decoded
    }

    func save(_ query: SavedFirestoreQuery, account: String, projectID: String) {
        var all = queries(account: account, projectID: projectID)
        all.removeAll { $0.id == query.id }
        all.insert(query, at: 0)
        persist(all, account: account, projectID: projectID)
    }

    func delete(id: String, account: String, projectID: String) {
        var all = queries(account: account, projectID: projectID)
        all.removeAll { $0.id == id }
        persist(all, account: account, projectID: projectID)
    }

    private func persist(_ queries: [SavedFirestoreQuery], account: String, projectID: String) {
        let key = keyPrefix + account + "." + projectID
        if let data = try? JSONEncoder().encode(queries) {
            defaults.set(data, forKey: key)
        }
    }
}

/// Firestore REST structured-query comparison operators.
enum FirestoreQueryOperator: String, Codable, Sendable, CaseIterable, Identifiable {
    case equal = "EQUAL"
    case lessThan = "LESS_THAN"
    case lessThanOrEqual = "LESS_THAN_OR_EQUAL"
    case greaterThan = "GREATER_THAN"
    case greaterThanOrEqual = "GREATER_THAN_OR_EQUAL"
    case arrayContains = "ARRAY_CONTAINS"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .equal: return "=="
        case .lessThan: return "<"
        case .lessThanOrEqual: return "<="
        case .greaterThan: return ">"
        case .greaterThanOrEqual: return ">="
        case .arrayContains: return "array-contains"
        }
    }
}

enum SavedQueryFilterValueKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case string
    case number
    case bool

    var id: String { rawValue }

    var label: String {
        switch self {
        case .string: return "String"
        case .number: return "Number"
        case .bool: return "Bool"
        }
    }
}

struct SavedFirestoreQuery: Codable, Sendable, Identifiable, Equatable {
    let id: String
    var title: String
    var collectionID: String
    var fieldPath: String?
    var op: String?
    var stringValue: String?
    var filterValueKind: SavedQueryFilterValueKind?
    var orderField: String?
    var descending: Bool
    var limit: Int
    var createdAt: Date

    static func make(
        title: String,
        collectionID: String,
        fieldPath: String? = nil,
        op: String? = nil,
        stringValue: String? = nil,
        filterValueKind: SavedQueryFilterValueKind? = nil,
        orderField: String? = nil,
        descending: Bool = false,
        limit: Int = 25
    ) -> SavedFirestoreQuery {
        SavedFirestoreQuery(
            id: UUID().uuidString,
            title: title,
            collectionID: collectionID,
            fieldPath: fieldPath,
            op: op,
            stringValue: stringValue,
            filterValueKind: filterValueKind,
            orderField: orderField,
            descending: descending,
            limit: limit,
            createdAt: .now
        )
    }

    func toStructuredQuery() -> FirestoreStructuredQuery {
        var query = FirestoreStructuredQuery(
            from: [.init(collectionId: collectionID)],
            where: nil,
            orderBy: nil,
            limit: limit
        )
        if let fieldPath, let op, let filterValue = filterFirestoreValue(), !fieldPath.isEmpty {
            query.`where` = .init(fieldFilter: .init(
                field: .init(fieldPath: fieldPath),
                op: op,
                value: filterValue
            ))
        }
        if let orderField, !orderField.isEmpty {
            query.orderBy = [.init(
                field: .init(fieldPath: orderField),
                direction: descending ? "DESCENDING" : "ASCENDING"
            )]
        }
        return query
    }

    func filterFirestoreValue() -> FirestoreValue? {
        guard let stringValue, !stringValue.isEmpty else { return nil }
        switch filterValueKind ?? .string {
        case .string:
            return .string(stringValue)
        case .bool:
            switch stringValue.lowercased() {
            case "true": return .boolean(true)
            case "false": return .boolean(false)
            default: return nil
            }
        case .number:
            if let integer = Int64(stringValue) { return .integer(integer) }
            if let double = Double(stringValue) { return .double(double) }
            return nil
        }
    }
}
