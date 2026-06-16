import SwiftData
import SwiftUI

@main
struct HeadacheApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            UserProfile.self,
            HeadacheEpisode.self,
            Medication.self,
            MedicationIntake.self
        ])
    }
}
