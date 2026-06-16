import Foundation

enum HeadacheValidators {
    static func normalizedPainLevel(_ value: Int) -> Int {
        min(max(value, 1), 10)
    }

    static func normalizedSleepHours(_ value: Double?) -> Double? {
        guard let value else { return nil }
        return min(max(value, 0), 24)
    }

    static func isValidTimeRange(startedAt: Date, endedAt: Date?) -> Bool {
        guard let endedAt else { return true }
        return endedAt >= startedAt
    }

    static func normalizedMedicationName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedProfileNumber(_ value: Int) -> Int {
        min(max(value, 0), 120)
    }
}

struct HeadacheStats {
    let episodeCount: Int
    let averagePainLevel: Double
    let averageDuration: TimeInterval?
    let medicationUsageCount: Int
    let commonLocations: [(HeadacheLocation, Int)]
    let commonTriggers: [(HeadacheTrigger, Int)]
    let painDistribution: [HeadacheLocation: PainSeverity]

    static func calculate(from episodes: [HeadacheEpisode]) -> HeadacheStats {
        let episodeCount = episodes.count
        let averagePain = episodes.isEmpty
            ? 0
            : Double(episodes.map(\.painLevel).reduce(0, +)) / Double(episodes.count)

        let durations = episodes.compactMap(\.duration)
        let averageDuration = durations.isEmpty
            ? nil
            : durations.reduce(0, +) / Double(durations.count)

        let medicationUsageCount = episodes.reduce(0) { $0 + $1.medicationIntakes.count }
        let locationCounts = Dictionary(
            episodes.flatMap(\.locations).map { ($0, 1) },
            uniquingKeysWith: +
        )
        let locationPainValues = Dictionary(
            grouping: episodes.flatMap { $0.locationPains.map { ($0.key, $0.value.rawValue) } },
            by: { $0.0 }
        )
        let triggerCounts = Dictionary(
            episodes.flatMap(\.triggers).map { ($0, 1) },
            uniquingKeysWith: +
        )

        let commonLocations = locationCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.title < rhs.key.title
                }
                return lhs.value > rhs.value
            }
        let commonTriggers = triggerCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.title < rhs.key.title
                }
                return lhs.value > rhs.value
            }
        let painDistribution = locationPainValues.reduce(into: [HeadacheLocation: PainSeverity]()) { result, item in
            let average = Double(item.value.map { $0.1 }.reduce(0, +)) / Double(item.value.count)
            let rounded = min(max(Int(average.rounded()), 1), 3)
            result[item.key] = PainSeverity(rawValue: rounded)
        }

        return HeadacheStats(
            episodeCount: episodeCount,
            averagePainLevel: averagePain,
            averageDuration: averageDuration,
            medicationUsageCount: medicationUsageCount,
            commonLocations: commonLocations,
            commonTriggers: commonTriggers,
            painDistribution: painDistribution
        )
    }
}
