import SwiftData
import SwiftUI
import UIKit

struct ReportPreviewView: View {
    @Query(sort: \HeadacheEpisode.startedAt, order: .reverse) private var episodes: [HeadacheEpisode]
    @Query private var profiles: [UserProfile]
    @State private var shareItem: ShareItem?
    @State private var errorMessage: String?

    private var latestProfile: UserProfile? {
        profiles.sorted { $0.updatedAt > $1.updatedAt }.first
    }

    private var report: HeadacheReport {
        HeadacheReportBuilder.build(episodes: episodes, profile: latestProfile)
    }

    var body: some View {
        List {
            if report.hasRedFlags {
                Section {
                    Label("如出现以下情况，建议及时就医或急诊评估。", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section("报告摘要") {
                ReportRow(title: "记录范围", value: report.recordRangeText)
                ReportRow(title: "总发作次数", value: "\(report.stats.episodeCount) 次")
                ReportRow(title: "平均疼痛等级", value: String(format: "%.1f / 10", report.stats.averagePainLevel))
                ReportRow(title: "平均持续时间", value: HeadacheFormatters.duration(report.stats.averageDuration))
                ReportRow(title: "药物使用次数", value: "\(report.stats.medicationUsageCount) 次")
                ReportRow(title: "近 30 天用药天数", value: "\(report.medicationDaysInLast30Days) 天")
            }

            Section("患者信息") {
                if let profile = latestProfile {
                    if !profile.patientName.isEmpty {
                        ReportRow(title: "姓名", value: profile.patientName)
                    }
                    if !profile.hospitalName.isEmpty {
                        ReportRow(title: "就诊医院", value: profile.hospitalName)
                    }
                    ReportRow(title: "性别", value: profile.gender.title)
                    ReportRow(title: "年龄", value: "\(profile.age) 岁")
                    ReportRow(title: "头痛年限", value: "\(profile.headacheYears) 年")
                } else {
                    Text("暂无基础信息")
                        .foregroundStyle(.secondary)
                }
            }

            Section("发作模式") {
                ReportRow(title: "常见位置", value: report.stats.commonLocations.prefix(3).map { "\($0.0.title) \($0.1) 次" }.joined(separator: "、").emptyFallback)
                ReportRow(title: "常见诱因", value: report.stats.commonTriggers.prefix(3).map { "\($0.0.title) \($0.1) 次" }.joined(separator: "、").emptyFallback)
                ReportRow(title: "疼痛性质", value: report.commonPainQualities.prefix(3).map { "\($0.0.title) \($0.1) 次" }.joined(separator: "、").emptyFallback)
                ReportRow(title: "伴随症状", value: report.commonAssociatedSymptoms.prefix(3).map { "\($0.0.title) \($0.1) 次" }.joined(separator: "、").emptyFallback)
            }

            Section {
                Button {
                    exportPDF()
                } label: {
                    Label("生成并分享 PDF", systemImage: "square.and.arrow.up")
                }
            } footer: {
                Text("报告仅用于辅助医生了解头痛记录，不提供医学诊断、疾病概率或治疗建议。")
            }
        }
        .navigationTitle("就诊报告")
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
        .alert("无法生成报告", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func exportPDF() {
        do {
            shareItem = ShareItem(url: try HeadacheReportPDFRenderer.render(report: report))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ReportRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private extension String {
    var emptyFallback: String {
        isEmpty ? "未记录" : self
    }
}
