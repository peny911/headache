import SwiftData
import SwiftUI

struct EpisodeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HeadacheEpisode.startedAt, order: .reverse) private var episodes: [HeadacheEpisode]
    @State private var isPresentingEditor = false
    @State private var editingEpisode: HeadacheEpisode?

    var body: some View {
        NavigationStack {
            List {
                if episodes.isEmpty {
                    ContentUnavailableView(
                        "暂无头痛记录",
                        systemImage: "calendar.badge.plus",
                        description: Text("点击右上角添加一次头痛发作记录。")
                    )
                } else {
                    ForEach(episodes) { episode in
                        Button {
                            editingEpisode = episode
                        } label: {
                            EpisodeRowView(episode: episode)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteEpisodes)
                }
            }
            .navigationTitle("头痛记录")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新增记录")
                }
            }
            .sheet(isPresented: $isPresentingEditor) {
                EpisodeEditView(episode: nil)
            }
            .sheet(item: $editingEpisode) { episode in
                EpisodeEditView(episode: episode)
            }
        }
    }

    private func deleteEpisodes(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(episodes[offset])
        }
    }
}

private struct EpisodeRowView: View {
    let episode: HeadacheEpisode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(HeadacheFormatters.dateTime.string(from: episode.startedAt))
                    .font(.headline)
                Spacer()
                Text("疼痛 \(episode.painLevel)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(painColor)
            }

            HStack(spacing: 10) {
                Label(HeadacheFormatters.duration(episode.duration), systemImage: "clock")
                if !episode.medicationIntakes.isEmpty {
                    Label("\(episode.medicationIntakes.count) 次用药", systemImage: "pills")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !episode.locationPains.isEmpty {
                Text(episode.locationPains.sorted { $0.key.title < $1.key.title }.map { "\($0.key.title)\($0.value.title)" }.joined(separator: "、"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !episode.triggers.isEmpty {
                Text("诱因：" + episode.triggers.map(\.title).joined(separator: "、"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var painColor: Color {
        switch episode.painLevel {
        case 1...3: .green
        case 4...6: .orange
        default: .red
        }
    }
}
