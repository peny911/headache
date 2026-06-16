import Foundation
import SwiftUI

enum HeadViewSide: String, CaseIterable, Identifiable {
    case front
    case back

    var id: String { rawValue }

    var title: String {
        switch self {
        case .front: "前视图"
        case .back: "后视图"
        }
    }
}

struct HeadPainMapPicker: View {
    @Binding var locationPains: [HeadacheLocation: PainSeverity]
    let gender: UserGender

    @State private var selectedSide: HeadViewSide = .front
    @State private var regionStore = HeadPainRegionStore.load()
#if DEBUG
    @State private var isRegionEditorPresented = false
#endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("头痛位置")
                    .font(.headline)
                Spacer()
#if DEBUG
                Button("编辑热区") {
                    isRegionEditorPresented = true
                }
                .font(.caption)
                Button("重新加载热区") {
                    regionStore = HeadPainRegionStore.load()
                }
                .font(.caption)
#endif
            }

            Picker("视图", selection: $selectedSide) {
                ForEach(HeadViewSide.allCases) { side in
                    Text(side.title).tag(side)
                }
            }
            .pickerStyle(.segmented)

            HeadPainMap(
                side: selectedSide,
                gender: gender,
                locationPains: locationPains,
                regionStore: regionStore
            ) { location in
                switch locationPains[location] {
                case nil:
                    locationPains[location] = .mild
                case .mild:
                    locationPains[location] = .moderate
                case .moderate:
                    locationPains[location] = .severe
                case .severe:
                    locationPains.removeValue(forKey: location)
                }
            }
#if DEBUG
            Text(regionStore.sourceDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("人物图：\(gender.title) / \(selectedSide.title)")
                .font(.caption2)
                .foregroundStyle(.secondary)
#endif

            PainLegend()

            if locationPains.isEmpty {
                Text("点击热区选择疼痛位置和程度")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
#if DEBUG
        .sheet(isPresented: $isRegionEditorPresented) {
            HeadPainRegionEditor(gender: gender) {
                regionStore = HeadPainRegionStore.load()
            }
        }
#endif
    }

    private var summary: String {
        locationPains
            .sorted { $0.key.title < $1.key.title }
            .map { "\($0.key.title)\($0.value.title)" }
            .joined(separator: "、")
    }
}

struct HeadPainDistributionMap: View {
    let title: String
    let side: HeadViewSide
    let gender: UserGender
    let locationPains: [HeadacheLocation: PainSeverity]
    @State private var regionStore = HeadPainRegionStore.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            HeadPainMap(
                side: side,
                gender: gender,
                locationPains: locationPains,
                regionStore: regionStore,
                onTap: nil
            )
        }
    }
}

private struct HeadPainMap: View {
    let side: HeadViewSide
    let gender: UserGender
    let locationPains: [HeadacheLocation: PainSeverity]
    let regionStore: HeadPainRegionStore
    let onTap: ((HeadacheLocation) -> Void)?

    var body: some View {
        if let errorMessage = regionStore.errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        } else {
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width, height: size.height)

                    ForEach(regionStore.regions(for: side, gender: gender)) { region in
                        regionView(region, in: size)
                    }
                }
            }
            .aspectRatio(0.68, contentMode: .fit)
        }
    }

    private var assetName: String {
        switch (gender, side) {
        case (.female, .front): "head_female_front"
        case (.female, .back): "head_female_back"
        case (.male, .front): "head_male_front"
        case (.male, .back): "head_male_back"
        }
    }

    private func regionView(_ region: HeadPainRegion, in size: CGSize) -> some View {
        let severity = locationPains[region.location]
        let shape = RegionShape(region: region)
        return shape
            .fill(severity.map { severityColor($0).opacity(0.48) } ?? Color.clear)
            .overlay {
                shape.stroke(severity.map { severityColor($0) } ?? Color.clear, lineWidth: severity == nil ? 0 : 2)
            }
            .contentShape(shape)
            .onTapGesture {
                onTap?(region.location)
            }
            .accessibilityLabel(region.location.title)
            .accessibilityValue(severity?.title ?? "未选择")
    }

    private func severityColor(_ severity: PainSeverity) -> Color {
        switch severity {
        case .mild: .yellow
        case .moderate: .orange
        case .severe: .red
        }
    }
}

private struct PainLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            legendItem("轻度", color: .yellow)
            legendItem("中度", color: .orange)
            legendItem("重度", color: .red)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendItem(_ title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color.opacity(0.65))
                .frame(width: 10, height: 10)
            Text(title)
        }
    }
}

private struct RegionShape: Shape {
    let region: HeadPainRegion

    func path(in rect: CGRect) -> Path {
        region.path(in: rect)
    }
}

struct HeadPainRegion: Identifiable {
    let location: HeadacheLocation
    let points: [CGPoint]

    var id: HeadacheLocation { location }

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

struct HeadPainRegionStore {
    let femaleFrontRegions: [HeadPainRegion]
    let femaleBackRegions: [HeadPainRegion]
    let maleFrontRegions: [HeadPainRegion]
    let maleBackRegions: [HeadPainRegion]
    let sourceDescription: String
    let errorMessage: String?

    static func load() -> HeadPainRegionStore {
        do {
            let regionsURL = try regionsURL()
            let data = try Data(contentsOf: regionsURL)
            let payload = try JSONDecoder().decode(HeadPainRegionPayload.self, from: data)
            return HeadPainRegionStore(
                femaleFrontRegions: try payload.regions(for: .front, gender: .female),
                femaleBackRegions: try payload.regions(for: .back, gender: .female),
                maleFrontRegions: try payload.regions(for: .front, gender: .male),
                maleBackRegions: try payload.regions(for: .back, gender: .male),
                sourceDescription: "热区来源：\(sourceDescription(for: regionsURL))",
                errorMessage: nil
            )
        } catch {
            return HeadPainRegionStore(
                femaleFrontRegions: [],
                femaleBackRegions: [],
                maleFrontRegions: [],
                maleBackRegions: [],
                sourceDescription: "热区来源：加载失败",
                errorMessage: "热区加载失败：\(error.localizedDescription)"
            )
        }
    }

    func regions(for side: HeadViewSide, gender: UserGender) -> [HeadPainRegion] {
        switch (gender, side) {
        case (.female, .front): femaleFrontRegions
        case (.female, .back): femaleBackRegions
        case (.male, .front): maleFrontRegions
        case (.male, .back): maleBackRegions
        }
    }

    static func regionsURL() throws -> URL {
        let fileManager = FileManager.default
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let documentsRegionsURL = documentsURL.appendingPathComponent("head_regions.json")
        if fileManager.fileExists(atPath: documentsRegionsURL.path) {
            return documentsRegionsURL
        }
#if DEBUG
        let projectRegionsURL = URL(fileURLWithPath: "/Users/patrick/Projects/Headache/Headache/head_regions.json")
        if fileManager.fileExists(atPath: projectRegionsURL.path) {
            return projectRegionsURL
        }
#endif
        if let bundleRegionsURL = Bundle.main.url(forResource: "head_regions", withExtension: "json") {
            return bundleRegionsURL
        }
        throw HeadPainRegionLoadError.missingFile
    }

#if DEBUG
    static var projectRegionsURL: URL {
        URL(fileURLWithPath: "/Users/patrick/Projects/Headache/Headache/head_regions.json")
    }

    static func documentsRegionsURL() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return documentsURL.appendingPathComponent("head_regions.json")
    }
#endif

    private static func sourceDescription(for url: URL) -> String {
        if url.path.contains("/Documents/head_regions.json") {
            return "Documents/head_regions.json"
        }
        if url.path == "/Users/patrick/Projects/Headache/Headache/head_regions.json" {
            return "工程 head_regions.json"
        }
        return "Bundle head_regions.json"
    }
}

private enum HeadPainRegionLoadError: LocalizedError {
    case missingFile
    case missingSide(UserGender, HeadViewSide)
    case invalidLocation(String)
    case invalidPointCount(String)
    case invalidCoordinate(String)

    var errorDescription: String? {
        switch self {
        case .missingFile: "未找到 head_regions.json"
        case .missingSide(let gender, let side): "head_regions.json 缺少 \(gender.title) / \(side.title)"
        case .invalidLocation(let rawValue): "未知热区位置：\(rawValue)"
        case .invalidPointCount(let location): "\(location) 至少需要 3 个坐标点"
        case .invalidCoordinate(let location): "\(location) 坐标必须是 [x, y] 且范围为 0...1"
        }
    }
}

private struct HeadPainRegionPayload: Decodable {
    let female: HeadPainGenderRegionPayload?
    let male: HeadPainGenderRegionPayload?
    let front: [String: [[Double]]]?
    let back: [String: [[Double]]]?

    func regions(for side: HeadViewSide, gender: UserGender) throws -> [HeadPainRegion] {
        let rawRegions: [String: [[Double]]]
        if let genderRegions = regionsByGender(for: gender) {
            guard let sideRegions = genderRegions.rawRegions(for: side) else {
                throw HeadPainRegionLoadError.missingSide(gender, side)
            }
            rawRegions = sideRegions
        } else {
            switch side {
            case .front:
                guard let front else { throw HeadPainRegionLoadError.missingSide(gender, side) }
                rawRegions = front
            case .back:
                guard let back else { throw HeadPainRegionLoadError.missingSide(gender, side) }
                rawRegions = back
            }
        }

        return try rawRegions.map { rawLocation, rawPoints in
            guard let location = HeadacheLocation(rawValue: rawLocation) else {
                throw HeadPainRegionLoadError.invalidLocation(rawLocation)
            }
            guard rawPoints.count >= 3 else {
                throw HeadPainRegionLoadError.invalidPointCount(location.title)
            }
            let points = try rawPoints.map { rawPoint in
                guard
                    rawPoint.count == 2,
                    (0...1).contains(rawPoint[0]),
                    (0...1).contains(rawPoint[1])
                else {
                    throw HeadPainRegionLoadError.invalidCoordinate(location.title)
                }
                return CGPoint(x: rawPoint[0], y: rawPoint[1])
            }
            return HeadPainRegion(location: location, points: points)
        }
        .sorted { $0.location.title < $1.location.title }
    }

    private func regionsByGender(for gender: UserGender) -> HeadPainGenderRegionPayload? {
        switch gender {
        case .female: female
        case .male: male
        }
    }
}

private struct HeadPainGenderRegionPayload: Decodable {
    let front: [String: [[Double]]]?
    let back: [String: [[Double]]]?

    func rawRegions(for side: HeadViewSide) -> [String: [[Double]]]? {
        switch side {
        case .front: front
        case .back: back
        }
    }
}
