import SwiftData
import SwiftUI

struct MedicationDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    var doseAmount: Double?
    var doseUnit: String
    var takenAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        doseAmount: Double? = nil,
        doseUnit: String = "mg",
        takenAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.takenAt = takenAt
    }
}

struct EpisodeEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Medication.lastUsedAt, order: .reverse) private var medications: [Medication]
    @Query private var profiles: [UserProfile]

    let episode: HeadacheEpisode?

    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var hasEndTime: Bool
    @State private var painLevel: Int
    @State private var sleepHoursText: String
    @State private var locationPains: [HeadacheLocation: PainSeverity]
    @State private var selectedTriggers: Set<HeadacheTrigger>
    @State private var note: String
    @State private var medicationDrafts: [MedicationDraft]
    @State private var validationMessage: String?

    init(episode: HeadacheEpisode?) {
        self.episode = episode
        _startedAt = State(initialValue: episode?.startedAt ?? .now)
        _endedAt = State(initialValue: episode?.endedAt ?? .now)
        _hasEndTime = State(initialValue: episode?.endedAt != nil)
        _painLevel = State(initialValue: episode?.painLevel ?? 5)
        _sleepHoursText = State(initialValue: episode?.sleepHours.map { String(format: "%.1f", $0) } ?? "")
        _locationPains = State(initialValue: episode?.locationPains ?? [:])
        _selectedTriggers = State(initialValue: Set(episode?.triggers ?? []))
        _note = State(initialValue: episode?.note ?? "")
        _medicationDrafts = State(initialValue: episode?.medicationIntakes
            .sorted { $0.takenAt < $1.takenAt }
            .map {
                MedicationDraft(
                    name: $0.nameSnapshot,
                    doseAmount: $0.doseAmount,
                    doseUnit: $0.doseUnit,
                    takenAt: $0.takenAt
                )
            } ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("时间") {
                    DatePicker("开始时间", selection: $startedAt)
                    Toggle("填写结束时间", isOn: $hasEndTime)
                    if hasEndTime {
                        DatePicker("结束时间", selection: $endedAt)
                    }
                }

                Section("疼痛") {
                    Stepper("疼痛等级 \(painLevel)", value: $painLevel, in: 1...10)
                    Slider(
                        value: Binding(
                            get: { Double(painLevel) },
                            set: { painLevel = Int($0.rounded()) }
                        ),
                        in: 1...10,
                        step: 1
                    )

                    HeadPainMapPicker(locationPains: $locationPains, gender: profileGender)
                        .frame(minHeight: 540)
                }

                Section("睡眠") {
                    TextField("睡眠时间（小时）", text: $sleepHoursText)
                        .keyboardType(.decimalPad)
                }

                Section("诱因") {
                    TriggerPicker(selection: $selectedTriggers)
                }

                Section("药物") {
                    ForEach($medicationDrafts) { $draft in
                        MedicationDraftEditor(draft: $draft, medications: medications)
                    }
                    .onDelete { offsets in
                        medicationDrafts.remove(atOffsets: offsets)
                    }

                    Button {
                        medicationDrafts.append(MedicationDraft(takenAt: startedAt))
                    } label: {
                        Label("添加服药记录", systemImage: "plus")
                    }
                }

                Section("备注") {
                    TextEditor(text: $note)
                        .frame(minHeight: 90)
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(episode == nil ? "新增记录" : "编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                }
            }
        }
    }

    private func save() {
        let sleepHours = Double(sleepHoursText.replacingOccurrences(of: ",", with: "."))
        let normalizedSleepHours = HeadacheValidators.normalizedSleepHours(sleepHours)
        let finalEndedAt = hasEndTime ? endedAt : nil

        guard HeadacheValidators.isValidTimeRange(startedAt: startedAt, endedAt: finalEndedAt) else {
            validationMessage = "结束时间不能早于开始时间。"
            return
        }

        let validMedicationDrafts = medicationDrafts.compactMap { draft -> MedicationDraft? in
            let name = HeadacheValidators.normalizedMedicationName(draft.name)
            let doseUnit = HeadacheValidators.normalizedMedicationName(draft.doseUnit)
            guard !name.isEmpty else { return nil }
            var copy = draft
            copy.name = name
            copy.doseUnit = doseUnit.isEmpty ? "mg" : doseUnit
            return copy
        }

        let target = episode ?? HeadacheEpisode(startedAt: startedAt)
        target.startedAt = startedAt
        target.endedAt = finalEndedAt
        target.painLevel = HeadacheValidators.normalizedPainLevel(painLevel)
        target.sleepHours = normalizedSleepHours
        target.locationPains = locationPains
        target.triggers = Array(selectedTriggers).sorted { $0.title < $1.title }
        target.note = note
        target.updatedAt = .now

        if episode == nil {
            modelContext.insert(target)
        }

        for intake in target.medicationIntakes {
            modelContext.delete(intake)
        }
        target.medicationIntakes.removeAll()

        for draft in validMedicationDrafts {
            let medication = medication(named: draft.name, unit: draft.doseUnit, doseAmount: draft.doseAmount, usedAt: draft.takenAt)
            let intake = MedicationIntake(
                nameSnapshot: medication.name,
                doseAmount: draft.doseAmount,
                doseUnit: draft.doseUnit,
                takenAt: draft.takenAt,
                episode: target,
                medication: medication
            )
            modelContext.insert(intake)
            target.medicationIntakes.append(intake)
        }

        dismiss()
    }

    private func medication(named name: String, unit: String, doseAmount: Double?, usedAt: Date) -> Medication {
        if let existing = medications.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            existing.defaultUnit = unit
            existing.lastDoseAmount = doseAmount
            existing.lastUsedAt = usedAt
            return existing
        }

        let newMedication = Medication(
            name: name,
            defaultUnit: unit,
            lastDoseAmount: doseAmount,
            lastUsedAt: usedAt
        )
        modelContext.insert(newMedication)
        return newMedication
    }

    private var profileGender: UserGender {
        profiles
            .sorted { $0.updatedAt > $1.updatedAt }
            .compactMap { UserGender(rawValue: $0.genderRawValue) }
            .first ?? .female
    }
}

private struct TriggerPicker: View {
    @Binding var selection: Set<HeadacheTrigger>

    var body: some View {
        FlowLayout(spacing: 8, rowSpacing: 8) {
            ForEach(HeadacheTrigger.allCases) { trigger in
                let isSelected = selection.contains(trigger)
                Button {
                    if isSelected {
                        selection.remove(trigger)
                    } else {
                        selection.insert(trigger)
                    }
                } label: {
                    Text(trigger.title)
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(isSelected ? .accentColor : .secondary)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat
    let rowSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth > 0, currentRowWidth + spacing + size.width > maxWidth {
                totalHeight += currentRowHeight + rowSpacing
                widestRow = max(widestRow, currentRowWidth)
                currentRowWidth = size.width
                currentRowHeight = size.height
            } else {
                currentRowWidth += currentRowWidth == 0 ? size.width : spacing + size.width
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }

        totalHeight += currentRowHeight
        widestRow = max(widestRow, currentRowWidth)

        return CGSize(width: maxWidth == 0 ? widestRow : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var origin = bounds.origin
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x > bounds.minX, origin.x + size.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += currentRowHeight + rowSpacing
                currentRowHeight = 0
            }

            subview.place(
                at: origin,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            origin.x += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

private struct MedicationDraftEditor: View {
    @Binding var draft: MedicationDraft
    let medications: [Medication]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("药名", text: $draft.name)

            if !matchingMedications.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(matchingMedications) { medication in
                            Button(medication.name) {
                                draft.name = medication.name
                                draft.doseUnit = medication.defaultUnit
                                draft.doseAmount = medication.lastDoseAmount
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            HStack {
                TextField(
                    "剂量",
                    value: $draft.doseAmount,
                    format: .number.precision(.fractionLength(0...2))
                )
                .keyboardType(.decimalPad)

                TextField("单位", text: $draft.doseUnit)
                    .frame(maxWidth: 80)
            }

            DatePicker("服用时间", selection: $draft.takenAt)
        }
        .padding(.vertical, 4)
    }

    private var matchingMedications: [Medication] {
        let query = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return Array(medications.prefix(6))
        }
        return medications
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .prefix(6)
            .map { $0 }
    }
}
