import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @AppStorage("hasCompletedProfile") private var hasCompletedProfile = false

    var body: some View {
        if !hasCompletedProfile {
            ProfileOnboardingView {
                hasCompletedProfile = true
            }
        } else {
            TabView {
                EpisodeListView()
                    .tabItem {
                        Label("记录", systemImage: "list.bullet.clipboard")
                    }

                StatsView()
                    .tabItem {
                        Label("统计", systemImage: "chart.xyaxis.line")
                    }

                MedicationListView()
                    .tabItem {
                        Label("药物", systemImage: "pills")
                    }

                ProfileSettingsView()
                    .tabItem {
                        Label("设置", systemImage: "gearshape")
                    }
            }
        }
    }
}
