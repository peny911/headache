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

    init(gender: UserGender, age: Int, headacheYears: Int, medicalHistory: String) {
        self.gender = gender
        self.age = age
        self.headacheYears = headacheYears
        self.medicalHistory = medicalHistory
    }

    init(profile: UserProfile) {
        self.gender = UserGender(rawValue: profile.genderRawValue) ?? .female
        self.age = profile.age
        self.headacheYears = profile.headacheYears
        self.medicalHistory = profile.medicalHistory
    }

    static var saved: ProfileDraft? {
        guard UserDefaults.standard.bool(forKey: "hasCompletedProfile") else { return nil }
        return ProfileDraft(
            gender: UserGender(rawValue: UserDefaults.standard.string(forKey: "profileGender") ?? "") ?? .female,
            age: UserDefaults.standard.integer(forKey: "profileAge"),
            headacheYears: UserDefaults.standard.integer(forKey: "profileHeadacheYears"),
            medicalHistory: UserDefaults.standard.string(forKey: "profileMedicalHistory") ?? ""
        )
    }

    func persist() {
        UserDefaults.standard.set(true, forKey: "hasCompletedProfile")
        UserDefaults.standard.set(gender.rawValue, forKey: "profileGender")
        UserDefaults.standard.set(age, forKey: "profileAge")
        UserDefaults.standard.set(headacheYears, forKey: "profileHeadacheYears")
        UserDefaults.standard.set(medicalHistory, forKey: "profileMedicalHistory")
    }
}

private struct ProfileForm: View {
    let draft: ProfileDraft?
    var requiresProfile = false
    let onSave: (ProfileDraft) -> Void

    @State private var gender: UserGender
    @State private var age: Int
    @State private var headacheYears: Int
    @State private var medicalHistory: String
    @State private var savedMessage: String?

    init(draft: ProfileDraft?, requiresProfile: Bool = false, onSave: @escaping (ProfileDraft) -> Void) {
        self.draft = draft
        self.requiresProfile = requiresProfile
        self.onSave = onSave
        _gender = State(initialValue: draft?.gender ?? .female)
        _age = State(initialValue: draft?.age ?? 30)
        _headacheYears = State(initialValue: draft?.headacheYears ?? 0)
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
                medicalHistory: medicalHistory
            )
        )
        savedMessage = "已保存"
    }
}
