import Foundation
import SwiftData

enum HeadacheLocation: String, CaseIterable, Identifiable, Codable {
    case forehead
    case leftTemple
    case rightTemple
    case top
    case leftBack
    case rightBack
    case leftOccipital
    case rightOccipital
    case leftGum
    case rightGum
    case leftAroundEyes
    case rightAroundEyes
    case leftCheekbone
    case rightCheekbone
    case leftNeck
    case rightNeck
    case leftBackNeck
    case rightBackNeck

    static let allCases: [HeadacheLocation] = [
        .forehead,
        .leftTemple,
        .rightTemple,
        .top,
        .leftBack,
        .rightBack,
        .leftOccipital,
        .rightOccipital,
        .leftGum,
        .rightGum,
        .leftAroundEyes,
        .rightAroundEyes,
        .leftCheekbone,
        .rightCheekbone,
        .leftNeck,
        .rightNeck,
        .leftBackNeck,
        .rightBackNeck
    ]

    static let frontCases: [HeadacheLocation] = [
        .forehead,
        .leftTemple,
        .rightTemple,
        .top,
        .leftAroundEyes,
        .rightAroundEyes,
        .leftCheekbone,
        .rightCheekbone,
        .leftGum,
        .rightGum,
        .leftNeck,
        .rightNeck
    ]

    static let backCases: [HeadacheLocation] = [
        .leftBack,
        .rightBack,
        .leftOccipital,
        .rightOccipital,
        .leftBackNeck,
        .rightBackNeck
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forehead: "前额"
        case .leftTemple: "左太阳穴"
        case .rightTemple: "右太阳穴"
        case .top: "头顶"
        case .leftBack: "左后脑"
        case .rightBack: "右后脑"
        case .leftOccipital: "左枕部"
        case .rightOccipital: "右枕部"
        case .leftGum: "左牙床"
        case .rightGum: "右牙床"
        case .leftAroundEyes: "左眼周"
        case .rightAroundEyes: "右眼周"
        case .leftCheekbone: "左颧骨"
        case .rightCheekbone: "右颧骨"
        case .leftNeck: "左颈"
        case .rightNeck: "右颈"
        case .leftBackNeck: "左后颈"
        case .rightBackNeck: "右后颈"
        }
    }
}

enum PainSeverity: Int, CaseIterable, Identifiable, Codable {
    case mild = 1
    case moderate = 2
    case severe = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .mild: "轻度"
        case .moderate: "中度"
        case .severe: "重度"
        }
    }

    var next: PainSeverity? {
        switch self {
        case .mild: .moderate
        case .moderate: .severe
        case .severe: nil
        }
    }

    static func next(after severity: PainSeverity?) -> PainSeverity? {
        severity?.next ?? .mild
    }
}

enum UserGender: String, CaseIterable, Identifiable, Codable {
    case male
    case female

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male: "男"
        case .female: "女"
        }
    }
}

enum HeadacheTrigger: String, CaseIterable, Identifiable, Codable {
    case stayingUpLate
    case stress
    case alcohol
    case weatherChange
    case emptyStomach
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stayingUpLate: "熬夜"
        case .stress: "压力"
        case .alcohol: "饮酒"
        case .weatherChange: "天气变化"
        case .emptyStomach: "空腹"
        case .unknown: "不明原因"
        }
    }
}

enum PainQuality: String, CaseIterable, Identifiable, Codable {
    case pulsating
    case pressing
    case stabbing
    case electric
    case distending
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pulsating: "搏动"
        case .pressing: "压迫/紧箍"
        case .stabbing: "针刺"
        case .electric: "电击"
        case .distending: "胀痛"
        case .other: "其他"
        }
    }
}

enum AssociatedSymptom: String, CaseIterable, Identifiable, Codable {
    case nausea
    case vomiting
    case photophobia
    case phonophobia
    case visualAura
    case numbnessOrWeakness
    case dizziness
    case tearingOrNasalCongestion
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nausea: "恶心"
        case .vomiting: "呕吐"
        case .photophobia: "畏光"
        case .phonophobia: "畏声"
        case .visualAura: "视觉先兆"
        case .numbnessOrWeakness: "麻木/无力"
        case .dizziness: "眩晕"
        case .tearingOrNasalCongestion: "流泪/鼻塞"
        case .other: "其他"
        }
    }
}

enum ActivityImpact: String, CaseIterable, Identifiable, Codable {
    case none
    case worsensWithActivity
    case needsRest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "不影响"
        case .worsensWithActivity: "活动后加重"
        case .needsRest: "需要休息/卧床"
        }
    }
}

enum ReliefEffect: String, CaseIterable, Identifiable, Codable {
    case untreated
    case spontaneous
    case sleep
    case medicationEffective
    case medicationIneffective

    var id: String { rawValue }

    var title: String {
        switch self {
        case .untreated: "未处理"
        case .spontaneous: "自行缓解"
        case .sleep: "睡眠缓解"
        case .medicationEffective: "用药后缓解"
        case .medicationIneffective: "用药无明显缓解"
        }
    }
}

enum RedFlagSymptom: String, CaseIterable, Identifiable, Codable {
    case thunderclap
    case feverOrNeckStiffness
    case afterTrauma
    case neurologicDeficit
    case progressiveWorsening
    case newTypeHeadache

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thunderclap: "突发最严重头痛"
        case .feverOrNeckStiffness: "发热/颈僵"
        case .afterTrauma: "外伤后头痛"
        case .neurologicDeficit: "神经异常"
        case .progressiveWorsening: "进行性加重"
        case .newTypeHeadache: "首次出现的新型头痛"
        }
    }
}

@Model
final class UserProfile {
    var id: UUID
    var genderRawValue: String
    var age: Int
    var headacheYears: Int
    var medicalHistory: String
    var patientName: String = ""
    var hospitalName: String = ""
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        gender: UserGender = .female,
        age: Int = 30,
        headacheYears: Int = 0,
        medicalHistory: String = "",
        patientName: String = "",
        hospitalName: String = "",
        updatedAt: Date = .now
    ) {
        self.id = id
        self.genderRawValue = gender.rawValue
        self.age = age
        self.headacheYears = headacheYears
        self.medicalHistory = medicalHistory
        self.patientName = patientName
        self.hospitalName = hospitalName
        self.updatedAt = updatedAt
    }

    var gender: UserGender {
        get { UserGender(rawValue: genderRawValue) ?? .female }
        set { genderRawValue = newValue.rawValue }
    }
}

@Model
final class HeadacheEpisode {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var painLevel: Int
    var sleepHours: Double?
    var locationPainRawValues: [String] = []
    var triggerRawValues: [String] = []
    var painQualityRawValues: [String] = []
    var associatedSymptomRawValues: [String] = []
    var activityImpactRawValue: String?
    var reliefEffectRawValue: String?
    var redFlagRawValues: [String] = []
    var note: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \MedicationIntake.episode)
    var medicationIntakes: [MedicationIntake]

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        painLevel: Int = 5,
        sleepHours: Double? = nil,
        locationPains: [HeadacheLocation: PainSeverity] = [:],
        triggers: [HeadacheTrigger] = [],
        painQualities: [PainQuality] = [],
        associatedSymptoms: [AssociatedSymptom] = [],
        activityImpact: ActivityImpact? = nil,
        reliefEffect: ReliefEffect? = nil,
        redFlags: [RedFlagSymptom] = [],
        note: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        medicationIntakes: [MedicationIntake] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.painLevel = painLevel
        self.sleepHours = sleepHours
        self.locationPainRawValues = locationPains.map { "\($0.key.rawValue):\($0.value.rawValue)" }
        self.triggerRawValues = triggers.map(\.rawValue)
        self.painQualityRawValues = painQualities.map(\.rawValue)
        self.associatedSymptomRawValues = associatedSymptoms.map(\.rawValue)
        self.activityImpactRawValue = activityImpact?.rawValue
        self.reliefEffectRawValue = reliefEffect?.rawValue
        self.redFlagRawValues = redFlags.map(\.rawValue)
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.medicationIntakes = medicationIntakes
    }

    var locationPains: [HeadacheLocation: PainSeverity] {
        get {
            Dictionary(
                locationPainRawValues.compactMap { rawValue in
                    let parts = rawValue.split(separator: ":")
                    guard
                        parts.count == 2,
                        let location = HeadacheLocation(rawValue: String(parts[0])),
                        let rawSeverity = Int(parts[1]),
                        let severity = PainSeverity(rawValue: rawSeverity)
                    else { return nil }
                    return (location, severity)
                },
                uniquingKeysWith: { _, latest in latest }
            )
        }
        set {
            locationPainRawValues = newValue
                .sorted { $0.key.title < $1.key.title }
                .map { "\($0.key.rawValue):\($0.value.rawValue)" }
        }
    }

    var locations: [HeadacheLocation] {
        locationPains.keys.sorted { $0.title < $1.title }
    }

    var triggers: [HeadacheTrigger] {
        get { triggerRawValues.compactMap(HeadacheTrigger.init(rawValue:)) }
        set { triggerRawValues = newValue.map(\.rawValue) }
    }

    var painQualities: [PainQuality] {
        get { painQualityRawValues.compactMap(PainQuality.init(rawValue:)) }
        set { painQualityRawValues = newValue.map(\.rawValue) }
    }

    var associatedSymptoms: [AssociatedSymptom] {
        get { associatedSymptomRawValues.compactMap(AssociatedSymptom.init(rawValue:)) }
        set { associatedSymptomRawValues = newValue.map(\.rawValue) }
    }

    var activityImpact: ActivityImpact? {
        get {
            guard let activityImpactRawValue else { return nil }
            return ActivityImpact(rawValue: activityImpactRawValue)
        }
        set { activityImpactRawValue = newValue?.rawValue }
    }

    var reliefEffect: ReliefEffect? {
        get {
            guard let reliefEffectRawValue else { return nil }
            return ReliefEffect(rawValue: reliefEffectRawValue)
        }
        set { reliefEffectRawValue = newValue?.rawValue }
    }

    var redFlags: [RedFlagSymptom] {
        get { redFlagRawValues.compactMap(RedFlagSymptom.init(rawValue:)) }
        set { redFlagRawValues = newValue.map(\.rawValue) }
    }

    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    var isActive: Bool {
        endedAt == nil
    }
}

@Model
final class Medication {
    var id: UUID
    var name: String
    var defaultUnit: String
    var lastDoseAmount: Double?
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        defaultUnit: String = "mg",
        lastDoseAmount: Double? = nil,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.defaultUnit = defaultUnit
        self.lastDoseAmount = lastDoseAmount
        self.lastUsedAt = lastUsedAt
    }
}

@Model
final class MedicationIntake {
    var id: UUID
    var nameSnapshot: String
    var doseAmount: Double?
    var doseUnit: String
    var takenAt: Date
    var episode: HeadacheEpisode?
    var medication: Medication?

    init(
        id: UUID = UUID(),
        nameSnapshot: String,
        doseAmount: Double? = nil,
        doseUnit: String = "mg",
        takenAt: Date = .now,
        episode: HeadacheEpisode? = nil,
        medication: Medication? = nil
    ) {
        self.id = id
        self.nameSnapshot = nameSnapshot
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.takenAt = takenAt
        self.episode = episode
        self.medication = medication
    }
}
