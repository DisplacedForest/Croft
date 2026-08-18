import Design
import GardenModel
import Persistence
import SwiftUI

import enum Domain.LifecycleStage
import enum Domain.PlantingStatus

@MainActor
enum ObservationPhotoAsset {
    private static var cache: [String: Image?] = [:]

    static func image(at relativePath: String?, in store: PhotoStore?) -> Image? {
        guard let relativePath, let store else {
            return nil
        }
        if let cached = cache[relativePath] {
            return cached
        }
        let loaded = load(relativePath, store)
        cache[relativePath] = loaded
        return loaded
    }

    private static func load(_ relativePath: String, _ store: PhotoStore) -> Image? {
        guard
            let url = try? store.url(forRelativePath: relativePath),
            let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        #if os(macOS)
            guard let platformImage = NSImage(data: data) else { return nil }
            return Image(nsImage: platformImage)
        #else
            guard let platformImage = UIImage(data: data) else { return nil }
            return Image(uiImage: platformImage)
        #endif
    }
}

struct PlantingTimelineSection: View {
    let timeline: PlantingTimeline
    let photos: PhotoStore?

    var body: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
            Text("Timeline")
                .font(.headline)
                .foregroundStyle(.secondary)
            if timeline.entries.isEmpty {
                Text("Nothing recorded yet. Log the planting date to start its story.")
                    .font(CroftTheme.supporting)
                    .foregroundStyle(.tertiary)
            } else {
                spine
            }
        }
    }

    private var spine: some View {
        VStack(spacing: 0) {
            ForEach(Array(timeline.entries.enumerated()), id: \.element.id) { index, entry in
                row(entry, alignedRight: index.isMultiple(of: 2))
            }
        }
        .background(alignment: .top) {
            Rectangle()
                .fill(Color.domainGarden.opacity(0.25))
                .frame(width: 2)
                .frame(maxWidth: .infinity)
        }
    }

    private func row(_ entry: PlantingTimeline.Entry, alignedRight: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            column(entry, shown: !alignedRight, alignment: .trailing)
                .padding(.trailing, CroftTheme.space(6))
            column(entry, shown: alignedRight, alignment: .leading)
                .padding(.leading, CroftTheme.space(6))
        }
        .padding(.bottom, CroftTheme.space(isPill(entry) ? 5 : 6))
        .overlay(alignment: .top) {
            node(entry)
                .offset(y: isPill(entry) ? CroftTheme.space(2) : CroftTheme.space(3))
        }
    }

    @ViewBuilder
    private func column(
        _ entry: PlantingTimeline.Entry,
        shown: Bool,
        alignment: Alignment
    ) -> some View {
        if shown {
            entryView(entry)
                .frame(maxWidth: .infinity, alignment: alignment)
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 1)
        }
    }

    private func node(_ entry: PlantingTimeline.Entry) -> some View {
        let diameter: CGFloat = isFirstHarvest(entry) ? 18 : isPill(entry) ? 12 : 14
        return Circle()
            .fill(tint(entry))
            .frame(width: diameter, height: diameter)
            .background(
                Circle()
                    .fill(Color.surfacePrimary)
                    .frame(width: diameter + 6, height: diameter + 6))
    }

    @ViewBuilder
    private func entryView(_ entry: PlantingTimeline.Entry) -> some View {
        if isPill(entry) {
            pill(entry)
        } else {
            card(entry)
        }
    }

    private func pill(_ entry: PlantingTimeline.Entry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CroftTheme.space(2)) {
            Text(entry.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint(entry))
            if let detail = entry.detail {
                Text("\(entry.date.gardenDisplay), \(detail)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(entry.date.gardenDisplay)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, CroftTheme.space(3.5))
        .padding(.vertical, CroftTheme.space(1.5))
        .background(tint(entry).opacity(0.12), in: Capsule())
    }

    private func card(_ entry: PlantingTimeline.Entry) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
            HStack(alignment: .firstTextBaseline) {
                Text(kindLabel(entry))
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(tint(entry))
                Spacer()
                Text(entry.date.gardenDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .center, spacing: CroftTheme.space(3)) {
                if let image = ObservationPhotoAsset.image(at: entry.photoPath, in: photos) {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                cardText(entry)
            }
        }
        .padding(CroftTheme.space(4))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            tint(entry).opacity(isFirstHarvest(entry) ? 0.14 : 0.1),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay {
            if isFirstHarvest(entry) {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(tint(entry).opacity(0.35))
            }
        }
    }

    private func cardText(_ entry: PlantingTimeline.Entry) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(1)) {
            HStack(alignment: .firstTextBaseline, spacing: CroftTheme.space(2)) {
                Text(entry.title)
                    .font(
                        .system(
                            isFirstHarvest(entry) ? .title3 : .callout,
                            design: .serif
                        )
                        .weight(.semibold))
                if let detail = entry.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let excerpt = entry.excerpt {
                Text(excerpt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func isPill(_ entry: PlantingTimeline.Entry) -> Bool {
        switch entry.kind {
        case .stage, .ended:
            true
        case .planted, .observation, .harvest:
            false
        }
    }

    private func isFirstHarvest(_ entry: PlantingTimeline.Entry) -> Bool {
        entry.kind == .harvest(first: true)
    }

    private func tint(_ entry: PlantingTimeline.Entry) -> Color {
        switch entry.kind {
        case .planted, .stage:
            Color.domainGarden
        case .observation(let threat):
            threat ? Color.domainHealth : Color.domainGarden
        case .harvest:
            Color.domainAnimals
        case .ended(let status):
            status == .failed ? Color.domainHealth : Color.domainGarden
        }
    }

    private func kindLabel(_ entry: PlantingTimeline.Entry) -> String {
        switch entry.kind {
        case .planted:
            "Planted"
        case .stage:
            "Stage"
        case .observation:
            "Observation"
        case .harvest(let first):
            first ? "First harvest" : "Harvest"
        case .ended(let status):
            status == .failed ? "Failed" : "Finished"
        }
    }
}
