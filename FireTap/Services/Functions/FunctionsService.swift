import Foundation

/// Cloud Functions listing across Gen1 (`v1`) and Gen2 (`v2`) APIs.
protocol FunctionsService: Sendable {
    /// Lists Gen1 and Gen2 functions for the project (all locations via `locations/-`).
    func listFunctions(projectID: String) async throws -> [CloudFunctionSummary]
    /// Invokes an HTTPS function endpoint. Returns status and body for any HTTP response.
    func invokeHTTP(
        url: URL,
        method: HTTPRequest.Method,
        headers: [String: String],
        body: Data?,
        attachBearer: Bool
    ) async throws -> FunctionHTTPInvokeResult
}

struct FunctionHTTPInvokeResult: Sendable, Equatable {
    let status: Int
    let body: String
}

struct LiveFunctionsService: FunctionsService {
    private let api: GoogleAPIClient
    private let transport: HTTPTransport
    private let gen1Base = URL(static: "https://cloudfunctions.googleapis.com/v1")
    private let gen2Base = URL(static: "https://cloudfunctions.googleapis.com/v2")

    init(api: GoogleAPIClient, transport: HTTPTransport = HTTPClient()) {
        self.api = api
        self.transport = transport
    }

    func listFunctions(projectID: String) async throws -> [CloudFunctionSummary] {
        async let gen1 = listGen1(projectID: projectID)
        async let gen2 = listGen2(projectID: projectID)
        let combined = try await gen1 + gen2
        return combined.sorted { $0.name < $1.name }
    }

    func invokeHTTP(
        url: URL,
        method: HTTPRequest.Method,
        headers: [String: String],
        body: Data?,
        attachBearer: Bool
    ) async throws -> FunctionHTTPInvokeResult {
        let request = HTTPRequest(method, url: url, headers: headers, body: body)
        let response: HTTPResponse
        if attachBearer {
            response = try await api.sendRawReturningStatus(request)
        } else {
            response = try await transport.sendReturningStatus(request, bearerToken: nil)
        }
        return FunctionHTTPInvokeResult(status: response.status, body: Self.truncateBody(response.data))
    }

    private static func truncateBody(_ data: Data) -> String {
        let limit = 8_000
        if let text = String(data: data, encoding: .utf8) {
            if text.count <= limit { return text.isEmpty ? "(empty body)" : text }
            return String(text.prefix(limit)) + "\n… (truncated)"
        }
        if data.isEmpty { return "(empty body)" }
        return "(binary data, \(data.count) bytes)"
    }

    private func listGen1(projectID: String) async throws -> [CloudFunctionSummary] {
        let url = gen1Base.appendingPathComponent("projects/\(projectID)/locations/-/functions")
        var summaries: [CloudFunctionSummary] = []
        var pageToken: String?
        repeat {
            var query: [URLQueryItem] = []
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let response: ListGen1FunctionsResponse = try await api.get(url: url, query: query)
            summaries.append(contentsOf: (response.functions ?? []).map { $0.asSummary(environment: "GEN_1") })
            pageToken = response.nextPageToken
        } while pageToken != nil
        return summaries
    }

    private func listGen2(projectID: String) async throws -> [CloudFunctionSummary] {
        let url = gen2Base.appendingPathComponent("projects/\(projectID)/locations/-/functions")
        var summaries: [CloudFunctionSummary] = []
        var pageToken: String?
        repeat {
            var query: [URLQueryItem] = []
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let response: ListGen2FunctionsResponse = try await api.get(url: url, query: query)
            summaries.append(contentsOf: (response.functions ?? []).map(\.asSummary))
            pageToken = response.nextPageToken
        } while pageToken != nil
        return summaries
    }
}

// MARK: - Domain model

struct CloudFunctionSummary: Sendable, Identifiable, Hashable, Equatable {
    /// Full resource name, e.g. `projects/P/locations/R/functions/F`.
    let name: String
    /// `GEN_1` or `GEN_2`.
    let environment: String
    let status: String?
    let region: String?
    let runtime: String?
    /// Human-readable trigger kind (`HTTPS`, `EVENT`, or raw type when known).
    let trigger: String?
    let url: String?
    let updateTime: String?

    var id: String { name }

    var displayName: String {
        name.split(separator: "/").last.map(String.init) ?? name
    }
}

// MARK: - Gen1 DTOs

private struct ListGen1FunctionsResponse: Decodable, Sendable {
    let functions: [Gen1Function]?
    let nextPageToken: String?
}

private struct Gen1Function: Decodable, Sendable {
    let name: String?
    let status: String?
    let updateTime: String?
    let runtime: String?
    let httpsTrigger: HTTPSTrigger?
    let eventTrigger: EventTrigger?

    struct HTTPSTrigger: Decodable, Sendable {
        let url: String?
    }

    struct EventTrigger: Decodable, Sendable {
        let eventType: String?
        let resource: String?
    }

    func asSummary(environment: String) -> CloudFunctionSummary {
        let trigger: String?
        let url: String?
        if let https = httpsTrigger {
            trigger = "HTTPS"
            url = https.url
        } else if let event = eventTrigger {
            trigger = event.eventType ?? "EVENT"
            url = nil
        } else {
            trigger = nil
            url = nil
        }
        return CloudFunctionSummary(
            name: name ?? "",
            environment: environment,
            status: status,
            region: regionFromName(name),
            runtime: runtime,
            trigger: trigger,
            url: url,
            updateTime: updateTime
        )
    }
}

// MARK: - Gen2 DTOs

private struct ListGen2FunctionsResponse: Decodable, Sendable {
    let functions: [Gen2Function]?
    let nextPageToken: String?
}

private struct Gen2Function: Decodable, Sendable {
    let name: String?
    let environment: String?
    let state: String?
    let updateTime: String?
    let buildConfig: BuildConfig?
    let serviceConfig: ServiceConfig?
    let eventTrigger: EventTrigger?

    struct BuildConfig: Decodable, Sendable {
        let runtime: String?
    }

    struct ServiceConfig: Decodable, Sendable {
        let uri: String?
    }

    struct EventTrigger: Decodable, Sendable {
        let eventType: String?
    }

    var asSummary: CloudFunctionSummary {
        let trigger: String?
        let url: String?
        if let uri = serviceConfig?.uri, !uri.isEmpty {
            trigger = "HTTPS"
            url = uri
        } else if let event = eventTrigger {
            trigger = event.eventType ?? "EVENT"
            url = nil
        } else {
            trigger = nil
            url = serviceConfig?.uri
        }
        return CloudFunctionSummary(
            name: name ?? "",
            environment: environment ?? "GEN_2",
            status: state,
            region: regionFromName(name),
            runtime: buildConfig?.runtime,
            trigger: trigger,
            url: url,
            updateTime: updateTime
        )
    }
}

private func regionFromName(_ name: String?) -> String? {
    guard let name else { return nil }
    let parts = name.split(separator: "/")
    // projects/{p}/locations/{region}/functions/{f}
    guard parts.count >= 4, parts[2] == "locations" else { return nil }
    return String(parts[3])
}
