import Foundation
import UIKit

struct HeadacheReport {
    let generatedAt: Date
    let profile: UserProfile?
    let episodes: [HeadacheEpisode]
    let stats: HeadacheStats
    let recordRangeText: String
    let hasRedFlags: Bool
    let commonPainQualities: [(PainQuality, Int)]
    let commonAssociatedSymptoms: [(AssociatedSymptom, Int)]
    let medicationSummaries: [MedicationSummary]
    let medicationDaysInLast30Days: Int
}

struct MedicationSummary: Identifiable {
    var id: String { name }
    let name: String
    let count: Int
    let lastUsedAt: Date
    let commonDoseText: String?
}

enum HeadacheReportBuilder {
    static func build(
        episodes: [HeadacheEpisode],
        profile: UserProfile?,
        generatedAt: Date = .now,
        calendar: Calendar = .current
    ) -> HeadacheReport {
        let sortedEpisodes = episodes.sorted { $0.startedAt > $1.startedAt }
        let stats = HeadacheStats.calculate(from: sortedEpisodes)
        let rangeText = recordRangeText(for: sortedEpisodes)
        let hasRedFlags = sortedEpisodes.contains { !$0.redFlags.isEmpty }
        let medicationSummaries = medicationSummaries(from: sortedEpisodes)
        let medicationDays = medicationDaysInLast30Days(
            from: sortedEpisodes,
            generatedAt: generatedAt,
            calendar: calendar
        )

        return HeadacheReport(
            generatedAt: generatedAt,
            profile: profile,
            episodes: sortedEpisodes,
            stats: stats,
            recordRangeText: rangeText,
            hasRedFlags: hasRedFlags,
            commonPainQualities: countedValues(sortedEpisodes.flatMap(\.painQualities)),
            commonAssociatedSymptoms: countedValues(sortedEpisodes.flatMap(\.associatedSymptoms)),
            medicationSummaries: medicationSummaries,
            medicationDaysInLast30Days: medicationDays
        )
    }

    private static func recordRangeText(for episodes: [HeadacheEpisode]) -> String {
        guard let first = episodes.min(by: { $0.startedAt < $1.startedAt })?.startedAt,
              let last = episodes.max(by: { $0.startedAt < $1.startedAt })?.startedAt
        else {
            return "暂无记录"
        }

        if Calendar.current.isDate(first, inSameDayAs: last) {
            return HeadacheFormatters.date.string(from: first)
        }

        return "\(HeadacheFormatters.date.string(from: first)) - \(HeadacheFormatters.date.string(from: last))"
    }

    private static func countedValues<Value: Hashable & Identifiable>(
        _ values: [Value]
    ) -> [(Value, Int)] where Value.ID == String {
        Dictionary(values.map { ($0, 1) }, uniquingKeysWith: +)
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.id < rhs.key.id
                }
                return lhs.value > rhs.value
            }
    }

    private static func medicationSummaries(from episodes: [HeadacheEpisode]) -> [MedicationSummary] {
        let intakes = episodes.flatMap(\.medicationIntakes)
        let grouped = Dictionary(grouping: intakes) { $0.nameSnapshot }

        return grouped.map { name, intakes in
            let doseCounts = Dictionary(
                intakes.compactMap { intake -> (String, Int)? in
                    guard let doseAmount = intake.doseAmount else { return nil }
                    return ("\(HeadacheFormatters.decimal.string(from: NSNumber(value: doseAmount)) ?? "\(doseAmount)") \(intake.doseUnit)", 1)
                },
                uniquingKeysWith: +
            )
            let commonDose = doseCounts.sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }.first?.key

            return MedicationSummary(
                name: name,
                count: intakes.count,
                lastUsedAt: intakes.map(\.takenAt).max() ?? .distantPast,
                commonDoseText: commonDose
            )
        }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.name < rhs.name
            }
            return lhs.count > rhs.count
        }
    }

    private static func medicationDaysInLast30Days(
        from episodes: [HeadacheEpisode],
        generatedAt: Date,
        calendar: Calendar
    ) -> Int {
        let start = calendar.date(byAdding: .day, value: -30, to: generatedAt) ?? .distantPast
        let days = episodes
            .flatMap(\.medicationIntakes)
            .filter { $0.takenAt >= start && $0.takenAt <= generatedAt }
            .map { calendar.startOfDay(for: $0.takenAt) }
        return Set(days).count
    }
}

enum HeadacheReportPDFRenderer {
    static func render(report: HeadacheReport) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("头痛就诊报告-\(formatter.string(from: report.generatedAt)).pdf")

        try renderer.writePDF(to: url) { context in
            let writer = PDFTextWriter(context: context, pageRect: pageRect)
            writer.beginPage()
            writer.write("头痛就诊参考报告", font: .boldSystemFont(ofSize: 24), color: .label, spacingAfter: 12)
            writer.write("本报告由用户记录生成，仅用于辅助医生了解头痛发作模式，不提供医学诊断、疾病概率或治疗建议。", font: .systemFont(ofSize: 10), color: .secondaryLabel, spacingAfter: 18)

            if report.hasRedFlags {
                writer.write("风险提示", font: .boldSystemFont(ofSize: 16), color: .systemRed, spacingAfter: 6)
                writer.write("如出现以下情况，建议及时就医或急诊评估。", font: .boldSystemFont(ofSize: 12), color: .systemRed, spacingAfter: 12)
            }

            writeSummary(report, writer: writer)
            writeProfile(report.profile, writer: writer)
            writePatterns(report, writer: writer)
            writeMedications(report, writer: writer)
            writeEpisodes(report, writer: writer)
        }

        return url
    }

    private static func writeSummary(_ report: HeadacheReport, writer: PDFTextWriter) {
        writer.writeSectionTitle("封面摘要")
        writer.writeKeyValues([
            ("生成时间", HeadacheFormatters.dateTime.string(from: report.generatedAt)),
            ("记录范围", report.recordRangeText),
            ("总发作次数", "\(report.stats.episodeCount) 次"),
            ("平均疼痛等级", String(format: "%.1f / 10", report.stats.averagePainLevel)),
            ("平均持续时间", HeadacheFormatters.duration(report.stats.averageDuration)),
            ("药物使用次数", "\(report.stats.medicationUsageCount) 次")
        ])
    }

    private static func writeProfile(_ profile: UserProfile?, writer: PDFTextWriter) {
        writer.writeSectionTitle("患者信息")
        guard let profile else {
            writer.write("暂无基础信息。", font: .systemFont(ofSize: 11), color: .secondaryLabel, spacingAfter: 8)
            return
        }

        var items: [(String, String)] = []
        if !profile.patientName.isEmpty {
            items.append(("姓名", profile.patientName))
        }
        if !profile.hospitalName.isEmpty {
            items.append(("就诊医院", profile.hospitalName))
        }
        items.append(("性别", profile.gender.title))
        items.append(("年龄", "\(profile.age) 岁"))
        items.append(("头痛年限", "\(profile.headacheYears) 年"))
        if !profile.medicalHistory.isEmpty {
            items.append(("病史描述", profile.medicalHistory))
        }
        writer.writeKeyValues(items)
    }

    private static func writePatterns(_ report: HeadacheReport, writer: PDFTextWriter) {
        writer.writeSectionTitle("发作模式")
        writer.writeKeyValues([
            ("常见位置", joined(report.stats.commonLocations.map { "\($0.0.title) \($0.1) 次" })),
            ("常见诱因", joined(report.stats.commonTriggers.map { "\($0.0.title) \($0.1) 次" })),
            ("常见疼痛性质", joined(report.commonPainQualities.map { "\($0.0.title) \($0.1) 次" })),
            ("常见伴随症状", joined(report.commonAssociatedSymptoms.map { "\($0.0.title) \($0.1) 次" }))
        ])
    }

    private static func writeMedications(_ report: HeadacheReport, writer: PDFTextWriter) {
        writer.writeSectionTitle("用药概览")
        writer.write("近 30 天用药天数：\(report.medicationDaysInLast30Days) 天", font: .systemFont(ofSize: 11), color: .label, spacingAfter: 6)

        if report.medicationSummaries.isEmpty {
            writer.write("暂无用药记录。", font: .systemFont(ofSize: 11), color: .secondaryLabel, spacingAfter: 8)
            return
        }

        for summary in report.medicationSummaries {
            var text = "\(summary.name)：\(summary.count) 次，最近 \(HeadacheFormatters.dateTime.string(from: summary.lastUsedAt))"
            if let commonDoseText = summary.commonDoseText {
                text += "，常见剂量 \(commonDoseText)"
            }
            writer.write("• \(text)", font: .systemFont(ofSize: 11), color: .label, spacingAfter: 4)
        }
        writer.addSpacing(6)
    }

    private static func writeEpisodes(_ report: HeadacheReport, writer: PDFTextWriter) {
        writer.writeSectionTitle("完整发作明细")
        guard !report.episodes.isEmpty else {
            writer.write("暂无头痛记录。", font: .systemFont(ofSize: 11), color: .secondaryLabel, spacingAfter: 8)
            return
        }

        for (index, episode) in report.episodes.enumerated() {
            writer.write("\(index + 1). \(HeadacheFormatters.dateTime.string(from: episode.startedAt))", font: .boldSystemFont(ofSize: 12), color: .label, spacingAfter: 4)
            writer.writeKeyValues([
                ("持续时间", HeadacheFormatters.duration(episode.duration)),
                ("疼痛等级", "\(episode.painLevel) / 10"),
                ("疼痛位置", joined(episode.locationPains.sorted { $0.key.title < $1.key.title }.map { "\($0.key.title)\($0.value.title)" })),
                ("疼痛性质", joined(episode.painQualities.map(\.title))),
                ("伴随症状", joined(episode.associatedSymptoms.map(\.title))),
                ("诱因", joined(episode.triggers.map(\.title))),
                ("睡眠", episode.sleepHours.map { "\($0) 小时" } ?? "未记录"),
                ("用药", joined(episode.medicationIntakes.sorted { $0.takenAt < $1.takenAt }.map(medicationText))),
                ("活动影响", episode.activityImpact?.title ?? "未记录"),
                ("缓解效果", episode.reliefEffect?.title ?? "未记录"),
                ("红旗项", joined(episode.redFlags.map(\.title))),
                ("备注", episode.note.isEmpty ? "无" : episode.note)
            ])
            writer.addSpacing(4)
        }
    }

    private static func medicationText(_ intake: MedicationIntake) -> String {
        var text = intake.nameSnapshot
        if let doseAmount = intake.doseAmount {
            text += " \(HeadacheFormatters.decimal.string(from: NSNumber(value: doseAmount)) ?? "\(doseAmount)") \(intake.doseUnit)"
        }
        text += "（\(HeadacheFormatters.dateTime.string(from: intake.takenAt))）"
        return text
    }

    private static func joined(_ values: [String]) -> String {
        values.isEmpty ? "未记录" : values.joined(separator: "、")
    }
}

private final class PDFTextWriter {
    private let context: UIGraphicsPDFRendererContext
    private let pageRect: CGRect
    private let margin: CGFloat = 44
    private var y: CGFloat = 44

    init(context: UIGraphicsPDFRendererContext, pageRect: CGRect) {
        self.context = context
        self.pageRect = pageRect
    }

    func beginPage() {
        context.beginPage()
        y = margin
    }

    func writeSectionTitle(_ title: String) {
        addSpacing(8)
        write(title, font: .boldSystemFont(ofSize: 16), color: .label, spacingAfter: 8)
    }

    func writeKeyValues(_ items: [(String, String)]) {
        for item in items {
            write("\(item.0)：\(item.1)", font: .systemFont(ofSize: 11), color: .label, spacingAfter: 4)
        }
        addSpacing(4)
    }

    func addSpacing(_ spacing: CGFloat) {
        y += spacing
        if y > pageRect.height - margin {
            beginPage()
        }
    }

    func write(_ text: String, font: UIFont, color: UIColor, spacingAfter: CGFloat) {
        let maxWidth = pageRect.width - margin * 2
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let lines = wrappedLines(for: text, font: font, maxWidth: maxWidth)
        let lineHeight = ceil(font.lineHeight + 2)

        for line in lines {
            if y + lineHeight > pageRect.height - margin {
                beginPage()
            }
            (line as NSString).draw(
                at: CGPoint(x: margin, y: y),
                withAttributes: attributes
            )
            y += lineHeight
        }
        y += spacingAfter
    }

    private func wrappedLines(for text: String, font: UIFont, maxWidth: CGFloat) -> [String] {
        let paragraphs = text.components(separatedBy: .newlines)
        return paragraphs.flatMap { paragraph -> [String] in
            guard !paragraph.isEmpty else { return [""] }
            var remaining = paragraph
            var lines: [String] = []

            while !remaining.isEmpty {
                let count = fittingPrefixLength(in: remaining, font: font, maxWidth: maxWidth)
                let index = remaining.index(remaining.startIndex, offsetBy: max(count, 1))
                lines.append(String(remaining[..<index]))
                remaining = String(remaining[index...])
            }
            return lines
        }
    }

    private func fittingPrefixLength(in text: String, font: UIFont, maxWidth: CGFloat) -> Int {
        var lower = 1
        var upper = text.count
        var best = 1

        while lower <= upper {
            let middle = (lower + upper) / 2
            let index = text.index(text.startIndex, offsetBy: middle)
            let candidate = String(text[..<index]) as NSString
            let size = candidate.size(withAttributes: [.font: font])
            if size.width <= maxWidth {
                best = middle
                lower = middle + 1
            } else {
                upper = middle - 1
            }
        }

        return best
    }
}
