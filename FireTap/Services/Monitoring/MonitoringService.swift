import Foundation

/// Cloud Monitoring `timeSeries.list` for a metric type + resource filter.
/// Returns an empty series when the API is unavailable (permission / not found)
/// so the UI can show an honest empty state rather than a fabricated chart.
protocol MonitoringService: Sendable {
    func listTimeSeries(
        projectID: String,
        metricType: String,
        resourceFilter: String?,
        startTime: Date,
        endTime: Date,
        pageSize: Int
    ) async throws -> [MetricPoint]
}

struct LiveMonitoringService: MonitoringService {
    private let api: GoogleAPIClient
    private let base = URL(static: "https://monitoring.googleapis.com/v3")

    init(api: GoogleAPIClient) {
        self.api = api
    }

    func listTimeSeries(
        projectID: String,
        metricType: String,
        resourceFilter: String?,
        startTime: Date,
        endTime: Date,
        pageSize: Int
    ) async throws -> [MetricPoint] {
        let url = base.appendingPathComponent("projects/\(projectID)/timeSeries")
        var filter = "metric.type=\"\(escapeFilter(metricType))\""
        if let resourceFilter, !resourceFilter.isEmpty {
            filter += " AND (\(resourceFilter))"
        }

        let formatter = ISO8601DateFormatter()
        let query = [
            URLQueryItem(name: "filter", value: filter),
            URLQueryItem(name: "interval.startTime", value: formatter.string(from: startTime)),
            URLQueryItem(name: "interval.endTime", value: formatter.string(from: endTime)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ]

        do {
            var points: [MetricPoint] = []
            var pageToken: String?
            repeat {
                var pageQuery = query
                if let pageToken {
                    pageQuery.append(URLQueryItem(name: "pageToken", value: pageToken))
                }
                let response: ListTimeSeriesResponse = try await api.get(url: url, query: pageQuery)
                for series in response.timeSeries ?? [] {
                    points.append(contentsOf: (series.points ?? []).compactMap(\.asMetricPoint))
                }
                pageToken = response.nextPageToken
            } while pageToken != nil
            return points.sorted { ($0.interval.endTime ?? "") < ($1.interval.endTime ?? "") }
        } catch let error as APIError {
            switch error {
            case .permissionDenied, .notFound:
                // API disabled, metric missing, or no access — honest empty.
                return []
            default:
                throw error
            }
        }
    }

    private func escapeFilter(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

// MARK: - Models

struct MetricPoint: Sendable, Equatable, Hashable {
    let interval: MetricInterval
    let value: Double
}

struct MetricInterval: Codable, Sendable, Equatable, Hashable {
    let startTime: String?
    let endTime: String?
}

// MARK: - DTOs

private struct ListTimeSeriesResponse: Decodable, Sendable {
    let timeSeries: [TimeSeries]?
    let nextPageToken: String?
}

private struct TimeSeries: Decodable, Sendable {
    let points: [TimeSeriesPoint]?
}

private struct TimeSeriesPoint: Decodable, Sendable {
    let interval: MetricInterval?
    let value: TypedValue?

    struct TypedValue: Decodable, Sendable {
        let doubleValue: Double?
        let int64Value: String?
        let boolValue: Bool?

        var asDouble: Double? {
            if let doubleValue { return doubleValue }
            if let int64Value, let parsed = Double(int64Value) { return parsed }
            if let boolValue { return boolValue ? 1 : 0 }
            return nil
        }
    }

    var asMetricPoint: MetricPoint? {
        guard let interval, let value = value?.asDouble else { return nil }
        return MetricPoint(interval: interval, value: value)
    }
}
