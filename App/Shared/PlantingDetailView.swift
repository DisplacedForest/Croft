import Design
import Domain
import GardenModel
import SwiftUI

struct PlantingDetailView: View {
    @Environment(GardenStore.self) private var store
    @Environment(CaptureStore.self) private var capture
    let plantingID: Planting.ID
    @State private var threatNames: Set<String> = []

    var body: some View {
        let capture = capture
        if let detail = store.plantingDetail(plantingID) {
            let timeline = store.plantingTimeline(
                plantingID,
                photos: capture.context?.photos,
                display: capture.context?.defaults.preferredUnitSystem ?? .metric,
                threatNames: threatNames)
            ScrollView {
                VStack(alignment: .leading, spacing: CroftTheme.space(6)) {
                    header(detail, stats: timeline?.stats)
                    facts(detail)
                    if let timeline {
                        PlantingTimelineSection(timeline: timeline, photos: capture.context?.photos)
                    }
                }
                .padding(CroftTheme.space(6))
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .task(id: capture.saveCount) {
                threatNames = ThreatNameIndex.names(from: capture.context?.knowledge)
            }
            .navigationTitle(detail.plantName)
            .toolbar {
                Button {
                    capture.present(.logObservation(.planting(plantingID), stage: nil))
                } label: {
                    Label("Log Observation", systemImage: "eye")
                }
                Button {
                    capture.present(.recordHarvest(plantingID))
                } label: {
                    Label("Record Harvest", systemImage: "basket")
                }
            }
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
        } else {
            ContentUnavailableView(
                "This planting is gone",
                systemImage: "leaf",
                description: Text("It may have been removed from another window.")
            )
        }
    }

    private func header(_ detail: PlantingDetail, stats: PlantingTimeline.Stats?) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
            HStack(alignment: .bottom, spacing: CroftTheme.space(4)) {
                Text(detail.plantName)
                    .font(CroftTheme.display)
                Spacer()
                if let stats {
                    statChips(stats)
                }
            }
            if let botanical = detail.botanicalName {
                Text(botanical)
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: CroftTheme.space(2)) {
                Text(detail.planting.status.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, CroftTheme.space(2))
                    .padding(.vertical, CroftTheme.space(1))
                    .background(
                        detail.planting.status == .active
                            ? AnyShapeStyle(.tint.opacity(0.15))
                            : AnyShapeStyle(.quaternary),
                        in: Capsule()
                    )
                    .foregroundStyle(
                        detail.planting.status == .active
                            ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                Text(locationLine(detail))
                    .font(CroftTheme.supporting)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func locationLine(_ detail: PlantingDetail) -> String {
        if let location = detail.locationName {
            return "\(detail.bedName), \(location)"
        }
        return detail.bedName
    }

    private func facts(_ detail: PlantingDetail) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
            if let lineage = detail.lineage {
                factRow("arrow.triangle.branch", lineage)
            }
            if let quantity = detail.planting.quantity {
                factRow("number", "\(quantity) plants")
            }
            if let spacing = detail.planting.spacingCentimeters {
                factRow(
                    "ruler",
                    "\(spacing.formatted(.number.precision(.fractionLength(0)))) cm apart")
            }
            if let maturity = detail.planting.expectedMaturityOn {
                factRow("calendar", "Expected to mature around \(maturity.gardenDisplay)")
            }
            if let notes = detail.planting.notes, !notes.isEmpty {
                factRow("text.alignleft", notes)
            }
        }
    }

    private func factRow(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text)
                .font(CroftTheme.supporting)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 20)
        }
    }

    private func statChips(_ stats: PlantingTimeline.Stats) -> some View {
        HStack(spacing: CroftTheme.space(2)) {
            if let days = stats.daysToFirstHarvest {
                statChip("\(days) days", "to first harvest")
            }
            if let yield = stats.totalYield {
                statChip(
                    yield,
                    stats.harvestCount == 1
                        ? "from 1 harvest" : "across \(stats.harvestCount) harvests")
            }
        }
    }

    private func statChip(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(0.5)) {
            Text(value)
                .font(.system(.body, design: .serif).weight(.semibold))
                .foregroundStyle(Color.domainGarden)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, CroftTheme.space(3.5))
        .padding(.vertical, CroftTheme.space(2.5))
        .background(Color.domainGarden.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}
