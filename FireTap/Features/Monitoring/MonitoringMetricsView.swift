import Charts
import SwiftUI

/// Cloud Monitoring time series for Cloud Functions invocation, error, and
/// latency metrics. Shows honest empty/delayed messaging when APIs return nothing.
struct MonitoringMetricsView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env
    @State private var phase: AsyncPhase<MonitoringMetricsSnapshot> = .idle

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                LoadingStateView().padding()
            case .failed(let error):
                ErrorStateView(error: error) { Task { await load() } }
            case .loaded(let snapshot):
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        if snapshot.isEmpty {
                            Card {
                                CardUnavailableNote(
                                    message: "Cloud Monitoring returned no time series for Cloud Functions in the last hour. Metrics can be delayed, the API may be disabled, or your account may lack monitoring.viewer access.",
                                    systemImage: "chart.line.uptrend.xyaxis"
                                )
                            }
                        } else {
                            metricCard(
                                title: "Invocations",
                                symbol: "bolt.fill",
                                points: snapshot.invocations,
                                color: Theme.Palette.info
                            )
                            metricCard(
                                title: "Errors",
                                symbol: "exclamationmark.triangle.fill",
                                points: snapshot.errors,
                                color: Theme.Palette.danger
                            )
                            metricCard(
                                title: "Execution time (ms, avg)",
                                symbol: "timer",
                                points: snapshot.latency,
                                color: Theme.Palette.warning
                            )
                        }
                        Text("Data from Cloud Monitoring `timeSeries.list`. Points may lag production by several minutes.")
                            .font(.pcCaption)
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                    .padding(Theme.Spacing.xl)
                }
                .refreshable { await load() }
            }
        }
        .appBackground()
        .navigationTitle("Monitoring")
        .navigationBarTitleDisplayMode(.inline)
        .task { if phase.value == nil { await load() } }
    }

    @ViewBuilder
    private func metricCard(title: String, symbol: String, points: [MetricPoint], color: Color) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Label(title, systemImage: symbol)
                    .font(.pcBodyEmphasis)
                    .foregroundStyle(color)
                if points.isEmpty {
                    Text("No data points")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                } else {
                    Chart(points, id: \.self) { point in
                        if let end = point.interval.endTime, let date = Self.parseDate(end) {
                            LineMark(
                                x: .value("Time", date),
                                y: .value(title, point.value)
                            )
                            .foregroundStyle(color)
                        }
                    }
                    .frame(height: 120)
                    Text("Latest: \(Self.formatValue(points.last?.value))")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
    }

    private func load() async {
        if phase.value == nil { phase = .loading }
        let end = Date()
        let start = end.addingTimeInterval(-3600)
        let resourceFilter = "resource.type=\"cloud_function\""
        do {
            async let invocations = env.monitoringService.listTimeSeries(
                projectID: project.projectId,
                metricType: "cloudfunctions.googleapis.com/function/execution_count",
                resourceFilter: resourceFilter,
                startTime: start,
                endTime: end,
                pageSize: 100
            )
            async let errors = env.monitoringService.listTimeSeries(
                projectID: project.projectId,
                metricType: "cloudfunctions.googleapis.com/function/user_errors",
                resourceFilter: resourceFilter,
                startTime: start,
                endTime: end,
                pageSize: 100
            )
            async let latency = env.monitoringService.listTimeSeries(
                projectID: project.projectId,
                metricType: "cloudfunctions.googleapis.com/function/execution_times",
                resourceFilter: resourceFilter,
                startTime: start,
                endTime: end,
                pageSize: 100
            )
            let snapshot = MonitoringMetricsSnapshot(
                invocations: try await invocations,
                errors: try await errors,
                latency: try await latency
            )
            phase = .loaded(snapshot)
        } catch let error as APIError {
            phase = .failed(error)
        } catch {
            phase = .failed(.transport(underlying: "unknown"))
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: value)
    }

    private static func formatValue(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value >= 1000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}

struct MonitoringMetricsSnapshot: Sendable, Equatable {
    let invocations: [MetricPoint]
    let errors: [MetricPoint]
    let latency: [MetricPoint]

    var isEmpty: Bool {
        invocations.isEmpty && errors.isEmpty && latency.isEmpty
    }
}
