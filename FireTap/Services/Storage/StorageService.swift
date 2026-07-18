import Foundation

/// Reads and writes Cloud Storage buckets and objects via the documented Cloud
/// Storage JSON API. Uses a delimiter so browsing is folder-scoped and never
/// lists an entire bucket implicitly.
protocol StorageService: Sendable {
    func listBuckets(projectID: String) async throws -> [StorageBucket]
    func listObjects(
        bucket: String,
        prefix: String,
        pageSize: Int,
        pageToken: String?
    ) async throws -> ListObjectsResponse
    func getObject(bucket: String, name: String) async throws -> StorageObject
    /// Downloads object media to a temp file. Callers must delete the file when done.
    func downloadObject(bucket: String, name: String) async throws -> StorageDownloadResult
    /// Simple media upload for smaller objects (Cloud Storage `uploadType=media`).
    func uploadObject(
        bucket: String,
        name: String,
        contentType: String?,
        data: Data
    ) async throws -> StorageObject
    func deleteObject(bucket: String, name: String) async throws
    /// Copy/rename via the rewrite API. Renaming is copy + delete on the client.
    func copyObject(
        bucket: String,
        sourceName: String,
        destinationName: String
    ) async throws -> StorageObject
}

struct StorageDownloadResult: Sendable {
    let fileURL: URL
    let byteCount: Int64
}

struct LiveStorageService: StorageService {
    private let api: GoogleAPIClient
    private let base = URL(static: "https://storage.googleapis.com/storage/v1")
    private let uploadBase = URL(static: "https://storage.googleapis.com/upload/storage/v1")

    /// Simple media uploads above this size use resumable upload.
    static let simpleUploadLimitBytes = 10 * 1_024 * 1_024
    /// Hard cap to avoid loading very large files entirely into memory.
    /// Streaming uploads from disk are planned for a future build.
    static let absoluteMaxUploadBytes = 100 * 1_024 * 1_024
    /// Chunk size for resumable uploads (256 KiB).
    static let resumableChunkBytes = 256 * 1_024

    init(api: GoogleAPIClient) {
        self.api = api
    }

    func listBuckets(projectID: String) async throws -> [StorageBucket] {
        let url = base.appendingPathComponent("b")
        var buckets: [StorageBucket] = []
        var pageToken: String?
        repeat {
            var query = [URLQueryItem(name: "project", value: projectID)]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let response: ListBucketsResponse = try await api.get(url: url, query: query)
            buckets.append(contentsOf: response.items ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil
        return buckets.sorted { $0.name < $1.name }
    }

    func listObjects(
        bucket: String,
        prefix: String,
        pageSize: Int,
        pageToken: String?
    ) async throws -> ListObjectsResponse {
        let encodedBucket = bucket.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bucket
        let url = base.appendingPathComponent("b/\(encodedBucket)/o")
        var query = [
            URLQueryItem(name: "delimiter", value: "/"),
            URLQueryItem(name: "maxResults", value: String(pageSize))
        ]
        if !prefix.isEmpty { query.append(URLQueryItem(name: "prefix", value: prefix)) }
        if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        return try await api.get(url: url, query: query)
    }

    func getObject(bucket: String, name: String) async throws -> StorageObject {
        let url = objectURL(bucket: bucket, name: name)
        return try await api.get(url: url)
    }

    func downloadObject(bucket: String, name: String) async throws -> StorageDownloadResult {
        let url = objectURL(bucket: bucket, name: name)
        let response = try await api.sendRaw(
            HTTPRequest(.get, url: url, query: [URLQueryItem(name: "alt", value: "media")], timeout: 120)
        )
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = name.split(separator: "/").last.map(String.init) ?? "download"
        let destination = tempDir
            .appendingPathComponent("firetap-\(UUID().uuidString)-\(fileName)", isDirectory: false)
        try response.data.write(to: destination, options: .atomic)
        return StorageDownloadResult(fileURL: destination, byteCount: Int64(response.data.count))
    }

    func uploadObject(
        bucket: String,
        name: String,
        contentType: String?,
        data: Data
    ) async throws -> StorageObject {
        guard data.count <= Self.absoluteMaxUploadBytes else {
            throw APIError.permissionDenied(
                message: "Files over \(StorageFormat.size(Int64(Self.absoluteMaxUploadBytes))) aren't supported yet. Uploads still load the full file into memory; streaming from disk is planned for a future build."
            )
        }
        let resolvedType = resolvedContentType(contentType)
        if data.count <= Self.simpleUploadLimitBytes {
            return try await simpleUpload(
                bucket: bucket,
                name: name,
                contentType: resolvedType,
                data: data
            )
        }
        return try await resumableUpload(
            bucket: bucket,
            name: name,
            contentType: resolvedType,
            data: data
        )
    }

    private func simpleUpload(
        bucket: String,
        name: String,
        contentType: String,
        data: Data
    ) async throws -> StorageObject {
        let encodedBucket = bucket.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bucket
        let url = uploadBase.appendingPathComponent("b/\(encodedBucket)/o")
        let response = try await api.sendRaw(
            HTTPRequest(
                .post,
                url: url,
                query: [
                    URLQueryItem(name: "uploadType", value: "media"),
                    URLQueryItem(name: "name", value: name)
                ],
                headers: ["Content-Type": contentType],
                body: data,
                timeout: 120
            )
        )
        return try JSONDecoder().decode(StorageObject.self, from: response.data)
    }

    private func resumableUpload(
        bucket: String,
        name: String,
        contentType: String,
        data: Data
    ) async throws -> StorageObject {
        let encodedBucket = bucket.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bucket
        let initiateURL = uploadBase.appendingPathComponent("b/\(encodedBucket)/o")
        let initiate = try await api.sendRaw(
            HTTPRequest(
                .post,
                url: initiateURL,
                query: [
                    URLQueryItem(name: "uploadType", value: "resumable"),
                    URLQueryItem(name: "name", value: name)
                ],
                headers: [
                    "X-Upload-Content-Type": contentType,
                    "X-Upload-Content-Length": String(data.count)
                ],
                body: nil,
                timeout: 120
            )
        )
        guard let location = initiate.location, let sessionURL = URL(string: location) else {
            throw APIError.invalidResponse
        }

        let total = data.count
        var offset = 0
        var lastResponse: HTTPResponse?
        while offset < total {
            let chunkEnd = min(offset + Self.resumableChunkBytes, total) - 1
            let chunk = data.subdata(in: offset..<(chunkEnd + 1))
            let rangeHeader = HTTPContentRange.header(start: offset, end: chunkEnd, total: total)
            let response = try await api.sendRaw(
                HTTPRequest(
                    .put,
                    url: sessionURL,
                    headers: [
                        "Content-Type": contentType,
                        "Content-Range": rangeHeader
                    ],
                    body: chunk,
                    timeout: 120,
                    acceptableAdditionalStatuses: [308]
                )
            )
            lastResponse = response
            offset = chunkEnd + 1
        }
        guard let lastResponse else {
            throw APIError.invalidResponse
        }
        return try JSONDecoder().decode(StorageObject.self, from: lastResponse.data)
    }

    private func resolvedContentType(_ contentType: String?) -> String {
        if let contentType, !contentType.isEmpty {
            return contentType
        }
        return "application/octet-stream"
    }

    func deleteObject(bucket: String, name: String) async throws {
        let url = objectURL(bucket: bucket, name: name)
        _ = try await api.sendVoid(HTTPRequest(.delete, url: url))
    }

    func copyObject(
        bucket: String,
        sourceName: String,
        destinationName: String
    ) async throws -> StorageObject {
        let encodedBucket = bucket.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bucket
        let encodedSource = encodedObjectPath(sourceName)
        let encodedDestination = encodedObjectPath(destinationName)
        let url = base.appendingPathComponent(
            "b/\(encodedBucket)/o/\(encodedSource)/rewriteTo/b/\(encodedBucket)/o/\(encodedDestination)"
        )
        return try await api.send(HTTPRequest(.post, url: url))
    }

    private func objectURL(bucket: String, name: String) -> URL {
        let encodedBucket = bucket.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bucket
        return base.appendingPathComponent("b/\(encodedBucket)/o/\(encodedObjectPath(name))")
    }

    private func encodedObjectPath(_ name: String) -> String {
        name.split(separator: "/")
            .map { segment -> String in
                String(segment).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(segment)
            }
            .joined(separator: "/")
    }
}
