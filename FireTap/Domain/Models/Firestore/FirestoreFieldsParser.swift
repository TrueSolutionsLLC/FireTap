import Foundation

enum FirestoreFieldsParserError: LocalizedError, Sendable, Equatable {
    case emptyInput
    case invalidJSON(String)
    case invalidSimpleLine(Int, String)
    case rootMustBeObject

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Enter at least one field or a JSON object."
        case .invalidJSON(let detail):
            return "Invalid JSON: \(detail)"
        case .invalidSimpleLine(let line, let content):
            return "Line \(line) is not valid (expected key: value): \(content)"
        case .rootMustBeObject:
            return "JSON must be an object with string keys."
        }
    }
}

/// Parses user-entered field text into Firestore REST field maps.
enum FirestoreFieldsParser: Sendable {
    /// Splits a collection path like `users/abc/posts` into query/create context.
    static func collectionContext(for collectionPath: String) -> FirestoreCollectionContext {
        FirestoreCollectionContext(collectionPath: collectionPath)
    }

    /// One field per line: `key: value` or `key=value`. Values infer bool, int, double, or string.
    static func parseSimple(_ text: String) throws -> [String: FirestoreValue] {
        var fields: [String: FirestoreValue] = [:]
        let lines = text.split(whereSeparator: \.isNewline)
        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("//") { continue }
            guard let separator = line.firstIndex(where: { $0 == ":" || $0 == "=" }) else {
                throw FirestoreFieldsParserError.invalidSimpleLine(index + 1, String(rawLine))
            }
            let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            let valueStart = line.index(after: separator)
            let valueText = line[valueStart...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                throw FirestoreFieldsParserError.invalidSimpleLine(index + 1, String(rawLine))
            }
            fields[key] = inferSimpleValue(valueText)
        }
        if fields.isEmpty, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw FirestoreFieldsParserError.invalidSimpleLine(1, text.components(separatedBy: .newlines).first ?? text)
        }
        return fields
    }

    /// Plain JSON object (`{"name":"Ada","count":3}`) mapped to Firestore values.
    static func parseJSON(_ text: String) throws -> [String: FirestoreValue] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [:] }
        let data = Data(trimmed.utf8)
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw FirestoreFieldsParserError.invalidJSON(error.localizedDescription)
        }
        guard let dictionary = object as? [String: Any] else {
            throw FirestoreFieldsParserError.rootMustBeObject
        }
        var fields: [String: FirestoreValue] = [:]
        fields.reserveCapacity(dictionary.count)
        for (key, value) in dictionary {
            guard let firestoreValue = firestoreValue(from: value) else {
                throw FirestoreFieldsParserError.invalidJSON("Unsupported value for key \"\(key)\".")
            }
            fields[key] = firestoreValue
        }
        return fields
    }

    static func inferSimpleValue(_ text: String) -> FirestoreValue {
        let lower = text.lowercased()
        if lower == "true" { return .boolean(true) }
        if lower == "false" { return .boolean(false) }
        if lower == "null" { return .null }
        if let intValue = Int64(text) { return .integer(intValue) }
        if let doubleValue = Double(text), text.contains(".") { return .double(doubleValue) }
        return .string(text)
    }

    static func firestoreValue(from json: Any) -> FirestoreValue? {
        switch json {
        case is NSNull:
            return .null
        case let boolean as Bool:
            return .boolean(boolean)
        case let integer as Int:
            return .integer(Int64(integer))
        case let integer as Int64:
            return .integer(integer)
        case let double as Double:
            return .double(double)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .boolean(number.boolValue)
            }
            let doubleValue = number.doubleValue
            if floor(doubleValue) == doubleValue, doubleValue <= Double(Int64.max), doubleValue >= Double(Int64.min) {
                return .integer(number.int64Value)
            }
            return .double(doubleValue)
        case let string as String:
            return .string(string)
        case let array as [Any]:
            return .array(array.compactMap { firestoreValue(from: $0) })
        case let dictionary as [String: Any]:
            let mapped = dictionary.compactMapValues { firestoreValue(from: $0) }
            return .map(mapped)
        default:
            return nil
        }
    }
}

struct FirestoreCollectionContext: Sendable, Equatable {
    let collectionID: String
    let parentDocumentPath: String?

    init(collectionPath: String) {
        let parts = collectionPath.split(separator: "/").map(String.init)
        if parts.count <= 1 {
            collectionID = collectionPath
            parentDocumentPath = nil
        } else {
            collectionID = parts.last ?? collectionPath
            parentDocumentPath = parts.dropLast().joined(separator: "/")
        }
    }
}
