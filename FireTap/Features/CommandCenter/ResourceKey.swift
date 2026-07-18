import Foundation

/// Stable preference keys for favorited or recently viewed resources.
enum ResourceKey {
    static func module(_ module: ServiceModule) -> String { "module:\(module.rawValue)" }
    static func firestoreCollection(_ name: String) -> String { "firestore:collection:\(name)" }
    static func firestoreDocument(path: String) -> String { "firestore:document:\(path)" }
    static func storageObject(bucket: String, name: String) -> String { "storage:object:\(bucket)/\(name)" }
    static func function(_ name: String) -> String { "functions:function:\(name)" }
    static func hostingSite(_ siteID: String) -> String { "hosting:site:\(siteID)" }
    static func authUser(_ uid: String) -> String { "authentication:user:\(uid)" }

    static func displayTitle(for key: String) -> String {
        let parts = key.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2 else { return key }
        switch parts[0] {
        case "module":
            return ServiceModule(rawValue: parts[1])?.title ?? parts[1]
        case "firestore":
            if parts.count >= 3, parts[1] == "collection" { return "Firestore · \(parts[2])" }
            if parts.count >= 3, parts[1] == "document" {
                return "Firestore doc · \(parts.dropFirst(2).joined(separator: ":"))"
            }
            return "Firestore · \(parts.dropFirst().joined(separator: " · "))"
        case "storage":
            return "Storage · \(parts.dropFirst(2).joined(separator: ":"))"
        case "functions":
            let name = parts.dropFirst(2).joined(separator: ":")
            return "Function · \(name.split(separator: "/").last.map(String.init) ?? name)"
        case "hosting":
            return "Hosting · \(parts.dropFirst(2).joined(separator: ":"))"
        case "authentication":
            return "Auth · \(parts.dropFirst(2).joined(separator: ":"))"
        default:
            return parts.dropFirst().joined(separator: " · ")
        }
    }

    static func serviceModule(for key: String) -> ServiceModule? {
        let prefix = key.split(separator: ":", maxSplits: 1).first.map(String.init)
        switch prefix {
        case "module":
            let raw = key.split(separator: ":", maxSplits: 1).dropFirst().first.map(String.init)
            return raw.flatMap(ServiceModule.init(rawValue:))
        case "firestore": return .firestore
        case "authentication", "auth": return .authentication
        case "storage": return .storage
        case "functions": return .functions
        case "hosting": return .hosting
        case "logs": return .logs
        case "rtdb", "realtimeDatabase": return .realtimeDatabase
        default: return nil
        }
    }
}

extension FireTapDeepLink {
    var module: ServiceModule? {
        moduleRawValue.flatMap(ServiceModule.init(rawValue:))
    }
}
