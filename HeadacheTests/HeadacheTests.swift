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

@Suite("Headache report")
struct HeadacheReportTests {
    @Test func emptyReportUsesReadableDefaults() {
        let report = HeadacheReportBuilder.build(
            episodes: [],
            profile: nil,
            generatedAt: Date(timeIntervalSince1970: 1_000)
        )

        #expect(report.recordRangeText == "暂无记录")
        #expect(report.stats.episodeCount == 0)
        #expect(!report.hasRedFlags)
        #expect(report.medicationSummaries.isEmpty)
        #expect(report.medicationDaysInLast30Days == 0)
    }

    @Test func reportIncludesAllEpisodesAndRanksClinicalFields() {
        let first = HeadacheEpisode(
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 3_600),
            painLevel: 4,
            painQualities: [.pulsating, .pressing],
            associatedSymptoms: [.nausea, .photophobia]
        )

        let second = HeadacheEpisode(
            startedAt: Date(timeIntervalSince1970: 7_200),
            endedAt: Date(timeIntervalSince1970: 10_800),
            painLevel: 8,
            painQualities: [.pulsating],
            associatedSymptoms: [.nausea],
            redFlags: [.thunderclap]
        )

        let report = HeadacheReportBuilder.build(episodes: [first, second], profile: nil)

        #expect(report.stats.episodeCount == 2)
        #expect(report.episodes.map(\.startedAt) == [second.startedAt, first.startedAt])
        #expect(report.commonPainQualities.first?.0 == .pulsating)
        #expect(report.commonPainQualities.first?.1 == 2)
        #expect(report.commonAssociatedSymptoms.first?.0 == .nausea)
        #expect(report.commonAssociatedSymptoms.first?.1 == 2)
        #expect(report.hasRedFlags)
    }

    @Test func medicationDaysAreDeduplicatedWithinLastThirtyDays() {
        let generatedAt = Date(timeIntervalSince1970: 2_592_000)
        let recentDay = generatedAt.addingTimeInterval(-86_400)
        let oldDay = generatedAt.addingTimeInterval(-31 * 86_400)
        let episode = HeadacheEpisode(startedAt: recentDay)
        episode.medicationIntakes = [
            MedicationIntake(nameSnapshot: "EVE", doseAmount: 1, doseUnit: "片", takenAt: recentDay),
            MedicationIntake(nameSnapshot: "EVE", doseAmount: 1, doseUnit: "片", takenAt: recentDay.addingTimeInterval(3_600)),
            MedicationIntake(nameSnapshot: "布洛芬", doseAmount: 200, doseUnit: "mg", takenAt: oldDay)
        ]

        let calendar = Calendar(identifier: .gregorian)
        let report = HeadacheReportBuilder.build(
            episodes: [episode],
            profile: nil,
            generatedAt: generatedAt,
            calendar: calendar
        )

        #expect(report.medicationDaysInLast30Days == 1)
        #expect(report.medicationSummaries.first?.name == "EVE")
        #expect(report.medicationSummaries.first?.count == 2)
    }

    @Test func newEpisodeFieldsDefaultToEmptyValues() {
        let episode = HeadacheEpisode()

        #expect(episode.painQualities.isEmpty)
        #expect(episode.associatedSymptoms.isEmpty)
        #expect(episode.activityImpact == nil)
        #expect(episode.reliefEffect == nil)
        #expect(episode.redFlags.isEmpty)
    }

    @Test func reportEnumTitlesAreStable() {
        #expect(PainQuality.pulsating.title == "搏动")
        #expect(AssociatedSymptom.photophobia.title == "畏光")
        #expect(ActivityImpact.needsRest.title == "需要休息/卧床")
        #expect(ReliefEffect.medicationIneffective.title == "用药无明显缓解")
        #expect(RedFlagSymptom.feverOrNeckStiffness.title == "发热/颈僵")
    }
}
