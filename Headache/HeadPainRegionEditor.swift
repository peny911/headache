#if DEBUG
import SwiftUI
import UIKit

struct HeadPainRegionEditor: View {
    let gender: UserGender
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedGender: UserGender
    @State private var selectedSide: HeadViewSide = .front
    @State private var selectedLocation: HeadacheLocation = .forehead
    @State private var selectedPointIndex: Int?
    @State private var regionsByKey: [HeadPainRegionEditKey: [EditableHeadPainRegion]] = [:]
    @State private var message: String?

    init(gender: UserGender, onSaved: @escaping () -> Void) {
        self.gender = gender
        self.onSaved = onSaved
        _selectedGender = State(initialValue: gender)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("性别", selection: $selectedGender) {
                    ForEach(UserGender.allCases) { gender in
                        Text(gender.title).tag(gender)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Picker("视图", selection: $selectedSide) {
                    ForEach(HeadViewSide.allCases) { side in
                        Text(side.title).tag(side)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                regionSelector
                    .padding(.horizontal)

                editorCanvas
                    .padding(.horizontal)

                pointControls
                    .padding(.horizontal)

                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .navigationTitle("热区编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Menu("导出") {
                        Button("复制当前视图到另一性别") {
                            copyCurrentSideToOtherGender()
                        }
                        Button("保存到工程文件") {
                            save(to: HeadPainRegionStore.projectRegionsURL)
                        }
                        Button("保存到 Documents") {
                            do {
                                save(to: try HeadPainRegionStore.documentsRegionsURL())
                            } catch {
                                message = "Documents 路径获取失败：\(error.localizedDescription)"
                            }
                        }
                        Button("复制 JSON") {
                            copyJSON()
                        }
                    }
                }
            }
        }
        .onAppear(perform: loadRegions)
        .onChange(of: selectedGender) { _, _ in
            refreshSelectedLocation()
        }
        .onChange(of: selectedSide) { _, _ in
            refreshSelectedLocation()
        }
    }

    private var regionSelector: some View {
        Picker("区域", selection: $selectedLocation) {
            ForEach(regions(for: selectedGender, side: selectedSide)) { region in
                Text(region.location.title).tag(region.location)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editorCanvas: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)

                ForEach(regions(for: selectedGender, side: selectedSide)) { region in
                    let isSelected = region.location == selectedLocation
                    EditableRegionShape(points: region.points)
                        .fill(isSelected ? Color.accentColor.opacity(0.20) : Color.gray.opacity(0.08))
                        .overlay {
                            EditableRegionShape(points: region.points)
                                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.45), lineWidth: isSelected ? 2 : 1)
                        }
                        .allowsHitTesting(false)
                }

                if let selectedRegion {
                    ForEach(Array(selectedRegion.points.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(index == selectedPointIndex ? Color.orange : Color.white)
                            .stroke(Color.accentColor, lineWidth: 1.5)
                            .frame(width: 12, height: 12)
                            .padding(10)
                            .contentShape(Circle())
                            .position(x: point.x * size.width, y: point.y * size.height)
                            .gesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .named("regionCanvas"))
                                    .onChanged { value in
                                        selectedPointIndex = index
                                        movePoint(at: index, to: normalized(value.location, in: size))
                                    }
                            )
                            .accessibilityLabel("\(selectedRegion.location.title) 顶点 \(index + 1)")
                    }
                }
            }
            .coordinateSpace(name: "regionCanvas")
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .aspectRatio(0.68, contentMode: .fit)
    }

    private var pointControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    appendPoint()
                } label: {
                    Label("新增顶点", systemImage: "plus.circle")
                }

                Button(role: .destructive) {
                    deleteSelectedPoint()
                } label: {
                    Label("删除顶点", systemImage: "minus.circle")
                }
                .disabled(selectedPointIndex == nil || (selectedRegion?.points.count ?? 0) <= 3)

                Spacer()
            }

            if let selectedPointDescription {
                Text(selectedPointDescription)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("拖动圆点调整热区边界")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
    }

    private var selectedRegion: EditableHeadPainRegion? {
        regions(for: selectedGender, side: selectedSide).first { $0.location == selectedLocation }
    }

    private var selectedPointDescription: String? {
        guard
            let selectedRegion,
            let selectedPointIndex,
            selectedRegion.points.indices.contains(selectedPointIndex)
        else {
            return nil
        }

        let point = selectedRegion.points[selectedPointIndex]
        return "顶点 \(selectedPointIndex + 1)：[\(formatted(point.x)), \(formatted(point.y))]"
    }

    private var assetName: String {
        switch (selectedGender, selectedSide) {
        case (.female, .front): "head_female_front"
        case (.female, .back): "head_female_back"
        case (.male, .front): "head_male_front"
        case (.male, .back): "head_male_back"
        }
    }

    private func loadRegions() {
        let store = HeadPainRegionStore.load()
        regionsByKey = [
            HeadPainRegionEditKey(gender: .female, side: .front): store.femaleFrontRegions.map { EditableHeadPainRegion(region: $0) },
            HeadPainRegionEditKey(gender: .female, side: .back): store.femaleBackRegions.map { EditableHeadPainRegion(region: $0) },
            HeadPainRegionEditKey(gender: .male, side: .front): store.maleFrontRegions.map { EditableHeadPainRegion(region: $0) },
            HeadPainRegionEditKey(gender: .male, side: .back): store.maleBackRegions.map { EditableHeadPainRegion(region: $0) }
        ]
        refreshSelectedLocation()
        message = store.sourceDescription
    }

    private func regions(for gender: UserGender, side: HeadViewSide) -> [EditableHeadPainRegion] {
        regionsByKey[HeadPainRegionEditKey(gender: gender, side: side)] ?? []
    }

    private func refreshSelectedLocation() {
        selectedLocation = regions(for: selectedGender, side: selectedSide).first?.location ?? .forehead
        selectedPointIndex = nil
    }

    private func normalized(_ location: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(location.x / max(size.width, 1), 0), 1),
            y: min(max(location.y / max(size.height, 1), 0), 1)
        )
    }

    private func movePoint(at index: Int, to point: CGPoint) {
        updateSelectedRegion { region in
            guard region.points.indices.contains(index) else { return }
            region.points[index] = point
        }
    }

    private func appendPoint() {
        updateSelectedRegion { region in
            let insertIndex = selectedPointIndex.map { min($0 + 1, region.points.count) } ?? region.points.count
            let newPoint = pointForInsertion(in: region, at: insertIndex)
            region.points.insert(newPoint, at: insertIndex)
            selectedPointIndex = insertIndex
        }
    }

    private func deleteSelectedPoint() {
        guard let selectedPointIndex else { return }
        updateSelectedRegion { region in
            guard region.points.count > 3, region.points.indices.contains(selectedPointIndex) else { return }
            region.points.remove(at: selectedPointIndex)
            self.selectedPointIndex = min(selectedPointIndex, region.points.count - 1)
        }
    }

    private func pointForInsertion(in region: EditableHeadPainRegion, at index: Int) -> CGPoint {
        guard !region.points.isEmpty else {
            return CGPoint(x: 0.5, y: 0.5)
        }

        let previous = region.points[(index - 1 + region.points.count) % region.points.count]
        let next = region.points[index % region.points.count]
        return CGPoint(x: (previous.x + next.x) / 2, y: (previous.y + next.y) / 2)
    }

    private func updateSelectedRegion(_ update: (inout EditableHeadPainRegion) -> Void) {
        let key = HeadPainRegionEditKey(gender: selectedGender, side: selectedSide)
        guard var regions = regionsByKey[key],
              let regionIndex = regions.firstIndex(where: { $0.location == selectedLocation })
        else {
            return
        }

        update(&regions[regionIndex])
        regionsByKey[key] = regions
    }

    private func copyCurrentSideToOtherGender() {
        let sourceKey = HeadPainRegionEditKey(gender: selectedGender, side: selectedSide)
        let targetGender = selectedGender == .female ? UserGender.male : UserGender.female
        let targetKey = HeadPainRegionEditKey(gender: targetGender, side: selectedSide)
        regionsByKey[targetKey] = regionsByKey[sourceKey] ?? []
        message = "已复制\(selectedGender.title) / \(selectedSide.title) 到\(targetGender.title) / \(selectedSide.title)"
    }

    private func save(to url: URL) {
        do {
            let json = try encodedJSON()
            guard let data = json.data(using: .utf8) else {
                message = "保存失败：JSON 编码失败"
                return
            }
            try data.write(to: url, options: .atomic)
            onSaved()
            message = "已保存：\(url.path)"
        } catch {
            message = "保存失败：\(error.localizedDescription)"
        }
    }

    private func copyJSON() {
        do {
            UIPasteboard.general.string = try encodedJSON()
            message = "JSON 已复制"
        } catch {
            message = "复制失败：\(error.localizedDescription)"
        }
    }

    private func encodedJSON() throws -> String {
        let payload: [String: [String: [String: [[Double]]]]] = [
            UserGender.female.rawValue: [
                HeadViewSide.front.rawValue: encodedRegions(for: .female, side: .front),
                HeadViewSide.back.rawValue: encodedRegions(for: .female, side: .back)
            ],
            UserGender.male.rawValue: [
                HeadViewSide.front.rawValue: encodedRegions(for: .male, side: .front),
                HeadViewSide.back.rawValue: encodedRegions(for: .male, side: .back)
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func encodedRegions(for gender: UserGender, side: HeadViewSide) -> [String: [[Double]]] {
        Dictionary(uniqueKeysWithValues: regions(for: gender, side: side).map { region in
            (
                region.location.rawValue,
                region.points.map { [rounded($0.x), rounded($0.y)] }
            )
        })
    }

    private func rounded(_ value: Double) -> Double {
        (value * 10_000).rounded() / 10_000
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.4f", value)
    }
}

private struct HeadPainRegionEditKey: Hashable {
    let gender: UserGender
    let side: HeadViewSide
}

private struct EditableHeadPainRegion: Identifiable {
    let location: HeadacheLocation
    var points: [CGPoint]

    var id: HeadacheLocation { location }

    init(location: HeadacheLocation, points: [CGPoint]) {
        self.location = location
        self.points = points
    }

    init(region: HeadPainRegion) {
        self.location = region.location
        self.points = region.points
    }
}

private struct EditableRegionShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: scaled(first, in: rect))
        for point in points.dropFirst() {
            path.addLine(to: scaled(point, in: rect))
        }
        path.closeSubpath()
        return path
    }

    private func scaled(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
    }
}
#endif
