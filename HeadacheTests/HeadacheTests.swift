import Foundation
import Testing
@testable import Headache

@Suite("Headache validators")
struct HeadacheValidatorTests {
    @Test func painLevelIsClampedToOneThroughTen() {
        #expect(HeadacheValidators.normalizedPainLevel(-1) == 1)
        #expect(HeadacheValidators.normalizedPainLevel(6) == 6)
        #expect(HeadacheValidators.normalizedPainLevel(12) == 10)
    }

    @Test func sleepHoursIsClampedToZeroThroughTwentyFour() {
        #expect(HeadacheValidators.normalizedSleepHours(nil) == nil)
        #expect(HeadacheValidators.normalizedSleepHours(-2) == 0)
        #expect(HeadacheValidators.normalizedSleepHours(7.5) == 7.5)
        #expect(HeadacheValidators.normalizedSleepHours(29) == 24)
    }

    @Test func timeRangeRequiresEndAfterStart() {
        let start = Date(timeIntervalSince1970: 1_000)
        #expect(HeadacheValidators.isValidTimeRange(startedAt: start, endedAt: nil))
        #expect(HeadacheValidators.isValidTimeRange(startedAt: start, endedAt: start))
        #expect(HeadacheValidators.isValidTimeRange(startedAt: start, endedAt: start.addingTimeInterval(60)))
        #expect(!HeadacheValidators.isValidTimeRange(startedAt: start, endedAt: start.addingTimeInterval(-60)))
    }

    @Test func medicationNameIsTrimmed() {
        #expect(HeadacheValidators.normalizedMedicationName("  EVE\n") == "EVE")
    }

    @Test func painSeverityCyclesThroughLevels() {
        #expect(PainSeverity.next(after: nil) == .mild)
        #expect(PainSeverity.next(after: .mild) == .moderate)
        #expect(PainSeverity.next(after: .moderate) == .severe)
        #expect(PainSeverity.next(after: .severe) == nil)
    }
}

@Suite("Headache stats")
struct HeadacheStatsTests {
    @Test func calculatesEpisodeSummary() {
        let first = HeadacheEpisode(
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 3_600),
            painLevel: 4,
            locationPains: [.forehead: .mild, .leftTemple: .severe]
        )
        first.medicationIntakes = [
            MedicationIntake(nameSnapshot: "EVE", doseAmount: 1, doseUnit: "片")
        ]

        let second = HeadacheEpisode(
            startedAt: Date(timeIntervalSince1970: 7_200),
            endedAt: Date(timeIntervalSince1970: 14_400),
            painLevel: 8,
            locationPains: [.forehead: .severe]
        )
        second.triggers = [.stayingUpLate, .stress]

        let stats = HeadacheStats.calculate(from: [first, second])
        #expect(stats.episodeCount == 2)
        #expect(stats.averagePainLevel == 6)
        #expect(stats.averageDuration == 5_400)
        #expect(stats.medicationUsageCount == 1)
        #expect(stats.commonLocations.first?.0 == .forehead)
        #expect(stats.commonLocations.first?.1 == 2)
        #expect(stats.commonTriggers.first?.0 == .stayingUpLate)
        #expect(stats.commonTriggers.first?.1 == 1)
        #expect(stats.painDistribution[.forehead] == .moderate)
    }
}
