import Charts
import SwiftData
import SwiftUI

struct StatsView: View {
    @Query(sort: \HeadacheEpisode.startedAt, order: .reverse) private var episodes: [HeadacheEpisode]
    @Query private var profiles: [UserProfile]
    @State private var range: StatsRange = .thirtyDays

    private var filteredEpisodes: [HeadacheEpisode] {
        let start = Calendar.current.date(byAdding: .day, value: -range.days, to: .now) ?? .distantPast
        return episodes.filter { $0.startedAt >= start }
    }

    private var stats: HeadacheStats {
        HeadacheStats.calculate(from: filteredEpisodes)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("统计范围", selection: $range) {
                        ForEach(StatsRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("概览") {
                    StatRow(title: "发作次数", value: "\(stats.episodeCount)")
                    StatRow(title: "平均疼痛等级", value: String(format: "%.1f", stats.averagePainLevel))
                    StatRow(title: "平均持续时间", value: HeadacheFormatters.duration(stats.averageDuration))
                    StatRow(title: "药物使用次数", value: "\(stats.medicationUsageCount)")
                }

                if !filteredEpisodes.isEmpty {
                    Section("疼痛分布") {
                        HeadPainDistributionMap(
                            title: "前视图",
                            side: .front,
                            gender: profileGender,
                            locationPains: stats.painDistribution
                        )
                        HeadPainDistributionMap(
                            title: "后视图",
                            side: .back,
                            gender: profileGender,
                            locationPains: stats.painDistribution
                        )
                    }

                    Section("疼痛趋势") {
                        Chart(filteredEpisodes.sorted { $0.startedAt < $1.startedAt }) { episode in
                            LineMark(
                                x: .value("日期", episode.startedAt),
                                y: .value("疼痛等级", episode.painLevel)
                            )
                            PointMark(
                                x: .value("日期", episode.startedAt),
                                y: .value("疼痛等级", episode.painLevel)
                            )
                        }
                        .chartYScale(domain: 1...10)
                        .frame(height: 220)
                    }
                }

                if !stats.commonLocations.isEmpty {
                    Section("常见位置") {
                        ForEach(stats.commonLocations, id: \.0) { location, count in
                            StatRow(title: location.title, value: "\(count)")
                        }
                    }
                }

                if !stats.commonTriggers.isEmpty {
                    Section("常见诱因") {
                        ForEach(stats.commonTriggers, id: \.0) { trigger, count in
                            StatRow(title: trigger.title, value: "\(count)")
                        }
                    }
                }
            }
            .navigationTitle("统计")
        }
    }

    private var profileGender: UserGender {
        savedProfileGender ?? profiles
            .sorted { $0.updatedAt > $1.updatedAt }
            .compactMap { UserGender(rawValue: $0.genderRawValue) }
            .first ?? .female
    }

    private var savedProfileGender: UserGender? {
        UserGender(rawValue: UserDefaults.standard.string(forKey: "profileGender") ?? "")
    }
}

private enum StatsRange: String, CaseIterable, Identifiable {
    case sevenDays
    case thirtyDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sevenDays: "近 7 天"
        case .thirtyDays: "近 30 天"
        }
    }

    var days: Int {
        switch self {
        case .sevenDays: 7
        case .thirtyDays: 30
        }
    }
}

private struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }
}
