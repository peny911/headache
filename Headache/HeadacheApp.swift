import SwiftData
import SwiftUI

@main
struct HeadacheApp: App {
    private let modelContainer: ModelContainer

    init() {
        modelContainer = HeadacheApp.makeModelContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            UserProfile.self,
            HeadacheEpisode.self,
            Medication.self,
            MedicationIntake.self
        ])

        do {
            return try ModelContainer(for: schema)
        } catch {
#if DEBUG
            resetDevelopmentStore()
            do {
                return try ModelContainer(for: schema)
            } catch {
                fatalError("Failed to create SwiftData container after reset: \(error)")
            }
#else
            fatalError("Failed to create SwiftData container: \(error)")
#endif
        }
    }

#if DEBUG
    private static func resetDevelopmentStore() {
        let fileManager = FileManager.default
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        let storeURL = applicationSupportURL.appendingPathComponent("default.store")
        let storePaths = [
            storeURL,
            applicationSupportURL.appendingPathComponent("default.store-shm"),
            applicationSupportURL.appendingPathComponent("default.store-wal")
        ]

        for url in storePaths where fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }
#endif
}
