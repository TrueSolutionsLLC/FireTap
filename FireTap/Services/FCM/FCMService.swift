import Foundation

/// Firebase Cloud Messaging HTTP v1 — send a test message to an explicit token.
protocol FCMService: Sendable {
    func sendTestMessage(projectID: String, message: FCMMessage) async throws -> FCMSendResponse
}

struct LiveFCMService: FCMService {
    private let api: GoogleAPIClient
    private let base = URL(static: "https://fcm.googleapis.com/v1")

    init(api: GoogleAPIClient) {
        self.api = api
    }

    func sendTestMessage(projectID: String, message: FCMMessage) async throws -> FCMSendResponse {
        guard let token = message.token, !token.isEmpty else {
            throw APIError.invalidResponse
        }
        let url = base.appendingPathComponent("projects/\(projectID)/messages:send")
        let body = try GoogleAPIClient.jsonBody(FCMSendRequest(message: message))
        return try await api.send(
            HTTPRequest(.post, url: url, headers: ["Content-Type": "application/json"], body: body)
        )
    }
}

// MARK: - Explicit token + payload structs

/// FCM v1 message targeting a single device registration token.
struct FCMMessage: Codable, Sendable, Equatable {
    /// Required device registration token.
    var token: String?
    var notification: FCMNotification?
    var data: [String: String]?
    var android: FCMAndroidConfig?
    var apns: FCMApnsConfig?
}

struct FCMNotification: Codable, Sendable, Equatable {
    var title: String?
    var body: String?
    var image: String?
}

struct FCMAndroidConfig: Codable, Sendable, Equatable {
    var priority: String?
    var ttl: String?
}

struct FCMApnsConfig: Codable, Sendable, Equatable {
    var headers: [String: String]?
    var payload: FCMApnsPayload?
}

struct FCMApnsPayload: Codable, Sendable, Equatable {
    var aps: FCMAps?
}

struct FCMAps: Codable, Sendable, Equatable {
    var alert: FCMApsAlert?
    var sound: String?
    var badge: Int?
}

struct FCMApsAlert: Codable, Sendable, Equatable {
    var title: String?
    var body: String?
}

struct FCMSendRequest: Encodable, Sendable {
    let message: FCMMessage
}

struct FCMSendResponse: Codable, Sendable, Equatable {
    /// Resource name of the sent message, e.g. `projects/{project}/messages/{id}`.
    let name: String?
}
