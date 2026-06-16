import SwiftData
import SwiftUI

struct MedicationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Medication.lastUsedAt, order: .reverse) private var medications: [Medication]

    var body: some View {
        NavigationStack {
            List {
                if medications.isEmpty {
                    ContentUnavailableView(
                        "暂无药物",
                        systemImage: "pills",
                        description: Text("在记录中添加药名后，会自动出现在这里。")
                    )
                } else {
                    ForEach(medications) { medication in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(medication.name)
                                .font(.headline)

                            HStack(spacing: 10) {
                                if let lastDoseAmount = medication.lastDoseAmount {
                                    Text("常用剂量 \(lastDoseAmount, format: .number.precision(.fractionLength(0...2))) \(medication.defaultUnit)")
                                } else {
                                    Text("单位 \(medication.defaultUnit)")
                                }

                                if let lastUsedAt = medication.lastUsedAt {
                                    Text("上次 \(HeadacheFormatters.date.string(from: lastUsedAt))")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteMedications)
                }
            }
            .navigationTitle("药物")
        }
    }

    private func deleteMedications(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(medications[offset])
        }
    }
}
