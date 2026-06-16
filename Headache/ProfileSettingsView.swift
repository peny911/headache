import SwiftData
import SwiftUI

struct ProfileSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var body: some View {
        NavigationStack {
            ProfileForm(draft: initialProfile) { draft in
                saveProfile(draft)
            }
            .navigationTitle("设置")
        }
    }

    private var latestProfile: UserProfile? {
        profiles.sorted { $0.updatedAt > $1.updatedAt }.first
    }

    private var initialProfile: ProfileDraft? {
        latestProfile.map(ProfileDraft.init(profile:)) ?? ProfileDraft.saved
    }

    private func saveProfile(_ draft: ProfileDraft) {
        let sortedProfiles = profiles.sorted { $0.updatedAt > $1.updatedAt }
        let target = sortedProfiles.first ?? UserProfile()
        target.genderRawValue = draft.gender.rawValue
        target.age = HeadacheValidators.normalizedProfileNumber(draft.age)
        target.headacheYears = HeadacheValidators.normalizedProfileNumber(draft.headacheYears)
        target.medicalHistory = draft.medicalHistory
        target.patientName = draft.patientName
        target.hospitalName = draft.hospitalName
        target.updatedAt = .now

        if sortedProfiles.isEmpty {
            modelContext.insert(target)
        }
        for duplicate in sortedProfiles.dropFirst() {
            modelContext.delete(duplicate)
        }
        draft.persist()
        try? modelContext.save()
    }
}

struct ProfileOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            ProfileForm(draft: ProfileDraft.saved, requiresProfile: true) { draft in
                let sortedProfiles = profiles.sorted { $0.updatedAt > $1.updatedAt }
                let target = sortedProfiles.first ?? UserProfile()
                target.genderRawValue = draft.gender.rawValue
                target.age = HeadacheValidators.normalizedProfileNumber(draft.age)
                target.headacheYears = HeadacheValidators.normalizedProfileNumber(draft.headacheYears)
                target.medicalHistory = draft.medicalHistory
                target.patientName = draft.patientName
                target.hospitalName = draft.hospitalName
                target.updatedAt = .now

                if sortedProfiles.isEmpty {
                    modelContext.insert(target)
                }
                for duplicate in sortedProfiles.dropFirst() {
                    modelContext.delete(duplicate)
                }
                draft.persist()
                try? modelContext.save()
                onComplete()
            }
            .navigationTitle("基础信息")
        }
    }
}

private struct ProfileDraft {
    var gender: UserGender
    var age: Int
    var headacheYears: Int
    var medicalHistory: String
    var patientName: String
    var hospitalName: String

    init(
        gender: UserGender,
        age: Int,
        headacheYears: Int,
        medicalHistory: String,
        patientName: String = "",
        hospitalName: String = ""
    ) {
        self.gender = gender
        self.age = age
        self.headacheYears = headacheYears
        self.medicalHistory = medicalHistory
        self.patientName = patientName
        self.hospitalName = hospitalName
    }

    init(profile: UserProfile) {
        self.gender = UserGender(rawValue: profile.genderRawValue) ?? .female
        self.age = profile.age
        self.headacheYears = profile.headacheYears
        self.medicalHistory = profile.medicalHistory
        self.patientName = profile.patientName
        self.hospitalName = profile.hospitalName
    }

    static var saved: ProfileDraft? {
        guard UserDefaults.standard.bool(forKey: "hasCompletedProfile") else { return nil }
        return ProfileDraft(
            gender: UserGender(rawValue: UserDefaults.standard.string(forKey: "profileGender") ?? "") ?? .female,
            age: UserDefaults.standard.integer(forKey: "profileAge"),
            headacheYears: UserDefaults.standard.integer(forKey: "profileHeadacheYears"),
            medicalHistory: UserDefaults.standard.string(forKey: "profileMedicalHistory") ?? "",
            patientName: UserDefaults.standard.string(forKey: "profilePatientName") ?? "",
            hospitalName: UserDefaults.standard.string(forKey: "profileHospitalName") ?? ""
        )
    }

    func persist() {
        UserDefaults.standard.set(true, forKey: "hasCompletedProfile")
        UserDefaults.standard.set(gender.rawValue, forKey: "profileGender")
        UserDefaults.standard.set(age, forKey: "profileAge")
        UserDefaults.standard.set(headacheYears, forKey: "profileHeadacheYears")
        UserDefaults.standard.set(medicalHistory, forKey: "profileMedicalHistory")
        UserDefaults.standard.set(patientName, forKey: "profilePatientName")
        UserDefaults.standard.set(hospitalName, forKey: "profileHospitalName")
    }
}

private struct ProfileForm: View {
    let draft: ProfileDraft?
    var requiresProfile = false
    let onSave: (ProfileDraft) -> Void

    @State private var gender: UserGender
    @State private var age: Int
    @State private var headacheYears: Int
    @State private var patientName: String
    @State private var hospitalName: String
    @State private var medicalHistory: String
    @State private var savedMessage: String?

    init(draft: ProfileDraft?, requiresProfile: Bool = false, onSave: @escaping (ProfileDraft) -> Void) {
        self.draft = draft
        self.requiresProfile = requiresProfile
        self.onSave = onSave
        _gender = State(initialValue: draft?.gender ?? .female)
        _age = State(initialValue: draft?.age ?? 30)
        _headacheYears = State(initialValue: draft?.headacheYears ?? 0)
        _patientName = State(initialValue: draft?.patientName ?? "")
        _hospitalName = State(initialValue: draft?.hospitalName ?? "")
        _medicalHistory = State(initialValue: draft?.medicalHistory ?? "")
    }

    var body: some View {
        Form {
            if requiresProfile {
                Section {
                    Text("请先填写基础信息，后续可在设置中修改。")
                        .foregroundStyle(.secondary)
                }
            }

            Section("基础信息") {
                Picker("性别", selection: $gender) {
                    ForEach(UserGender.allCases) { gender in
                        Text(gender.title).tag(gender)
                    }
                }
                .pickerStyle(.segmented)

                Stepper("年龄 \(age) 岁", value: $age, in: 0...120)
                Stepper("头痛 \(headacheYears) 年", value: $headacheYears, in: 0...120)
            }

            Section("就诊报告") {
                TextField("姓名（可选）", text: $patientName)
                    .textContentType(.name)
                TextField("就诊医院（可选）", text: $hospitalName)
            }

            Section("病史描述") {
                TextEditor(text: $medicalHistory)
                    .frame(minHeight: 140)
            }

            if let savedMessage {
                Section {
                    Text(savedMessage)
                        .foregroundStyle(.secondary)
                }
            }

#if DEBUG
            Section("调试") {
                Text("当前选择：\(gender.title) / \(gender.rawValue)")
                    .foregroundStyle(.secondary)
            }
#endif
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
            }
        }
    }

    private func save() {
        onSave(
            ProfileDraft(
                gender: gender,
                age: age,
                headacheYears: headacheYears,
                medicalHistory: medicalHistory,
                patientName: HeadacheValidators.normalizedMedicationName(patientName),
                hospitalName: HeadacheValidators.normalizedMedicationName(hospitalName)
            )
        )
        savedMessage = "已保存"
    }
}
