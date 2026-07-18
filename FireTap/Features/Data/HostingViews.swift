import SwiftUI

struct HostingSiteDetailView: View {
    let project: FirebaseProject
    let site: HostingSite

    @Environment(AppEnvironment.self) private var env
    @State private var channelsPhase: AsyncPhase<[HostingChannel]> = .idle

    private var accountID: String { env.accountManager.activeAccountID ?? "anonymous" }
    private var resourceKey: String { ResourceKey.hostingSite(site.siteID) }

    var body: some View {
        Group {
            switch channelsPhase {
            case .idle, .loading:
                LoadingStateView().padding()
            case .failed(let error):
                ErrorStateView(error: error) { Task { await loadChannels() } }
            case .loaded(let channels):
                List {
                    siteSection
                    Section("Channels • \(channels.count)") {
                        if channels.isEmpty {
                            Text("No channels returned for this site.")
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .listRowBackground(Theme.Palette.surface)
                        }
                        ForEach(channels) { channel in
                            NavigationLink {
                                HostingChannelDetailView(project: project, site: site, channel: channel)
                            } label: {
                                hostingChannelRow(channel)
                            }
                            .listRowBackground(Theme.Palette.surface)
                        }
                    }
                    Section {
                        Text("Source deploy and channel management are not available from FireTap on iPhone. This view lists live channels and releases only.")
                            .font(.pcCaption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .refreshable { await loadChannels() }
            }
        }
        .appBackground()
        .navigationTitle(site.siteID)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            env.preferences.recordRecentlyViewed(resourceKey, account: accountID)
            if channelsPhase.value == nil { await loadChannels() }
        }
    }

    private var siteSection: some View {
        Section("Site") {
            if let url = site.defaultUrl {
                LabeledContent("Default URL") {
                    Text(url)
                        .font(.pcMonoSmall)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
            }
            if let type = site.type {
                LabeledContent("Type", value: type)
            }
            if let appId = site.appId {
                LabeledContent("App ID", value: appId)
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private func hostingChannelRow(_ channel: HostingChannel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(channel.channelID)
                .font(.pcBodyEmphasis)
            if let url = channel.url {
                Text(url)
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }
            if let expireTime = channel.expireTime {
                Text("Expires \(expireTime)")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
    }

    private func loadChannels() async {
        if channelsPhase.value == nil { channelsPhase = .loading }
        do {
            let channels = try await env.hostingService.listChannels(siteID: site.siteID)
            channelsPhase = .loaded(channels)
        } catch let error as APIError {
            channelsPhase = .failed(error)
        } catch {
            channelsPhase = .failed(.transport(underlying: "unknown"))
        }
    }
}

struct HostingChannelDetailView: View {
    let project: FirebaseProject
    let site: HostingSite
    let channel: HostingChannel

    @Environment(AppEnvironment.self) private var env
    @State private var releasesPhase: AsyncPhase<[HostingRelease]> = .idle

    var body: some View {
        Group {
            switch releasesPhase {
            case .idle, .loading:
                LoadingStateView().padding()
            case .failed(let error):
                ErrorStateView(error: error) { Task { await loadReleases() } }
            case .loaded(let releases):
                List {
                    channelSection
                    Section("Releases • \(releases.count)") {
                        if releases.isEmpty {
                            Text("No releases returned for this channel.")
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .listRowBackground(Theme.Palette.surface)
                        }
                        ForEach(releases) { release in
                            hostingReleaseRow(release)
                                .listRowBackground(Theme.Palette.surface)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .refreshable { await loadReleases() }
            }
        }
        .appBackground()
        .navigationTitle(channel.channelID)
        .navigationBarTitleDisplayMode(.inline)
        .task { if releasesPhase.value == nil { await loadReleases() } }
    }

    private var channelSection: some View {
        Section("Channel") {
            if let url = channel.url {
                LabeledContent("URL") {
                    Text(url)
                        .font(.pcMonoSmall)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
            }
            if let expireTime = channel.expireTime {
                LabeledContent("Expire time", value: expireTime)
            }
            if let createTime = channel.createTime {
                LabeledContent("Created", value: createTime)
            }
            if let updateTime = channel.updateTime {
                LabeledContent("Updated", value: updateTime)
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private func hostingReleaseRow(_ release: HostingRelease) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let releaseTime = release.releaseTime {
                Text(releaseTime)
                    .font(.pcBodyEmphasis)
            } else {
                Text("Release")
                    .font(.pcBodyEmphasis)
            }
            if let type = release.type {
                Text("Type · \(type)")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            if let status = release.version?.status {
                Text("Version status · \(status)")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            } else {
                Text("Version status · unknown")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            if let message = release.message, !message.isEmpty {
                Text(message)
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(3)
            }
        }
    }

    private func loadReleases() async {
        if releasesPhase.value == nil { releasesPhase = .loading }
        do {
            let response = try await env.hostingService.listReleases(
                siteID: site.siteID,
                channelID: channel.channelID,
                pageSize: 25,
                pageToken: nil
            )
            releasesPhase = .loaded(response.releases ?? [])
        } catch let error as APIError {
            releasesPhase = .failed(error)
        } catch {
            releasesPhase = .failed(.transport(underlying: "unknown"))
        }
    }
}
