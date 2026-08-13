import Domain
import GardenModel
import SwiftUI

struct PlantingDetailView: View {
    @Environment(GardenStore.self) private var store
    let plantingID: Planting.ID

    var body: some View {
        if let detail = store.plantingDetail(plantingID) {
            ScrollView {
                VStack(alignment: .leading, spacing: CroftTheme.space(6)) {
                    header(detail)
                    facts(detail)
                    timeline(detail)
                    historyScaffold
                }
                .padding(CroftTheme.space(6))
                .frame(maxWidth: 640, alignment: .leading)
            }
            .navigationTitle(detail.plantName)
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

    private func header(_ detail: PlantingDetail) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
            Text(detail.plantName)
                .font(CroftTheme.display)
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

    private func timeline(_ detail: PlantingDetail) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
            Text("Timeline")
                .font(.headline)
                .foregroundStyle(.secondary)
            if detail.timeline.isEmpty {
                Text("No dates recorded yet.")
                    .font(CroftTheme.supporting)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
                    ForEach(Array(detail.timeline.enumerated()), id: \.offset) { _, event in
                        HStack(spacing: CroftTheme.space(3)) {
                            Circle()
                                .fill(.tint)
                                .frame(width: 6, height: 6)
                            Text(event.kind.displayName)
                                .font(.body.weight(.medium))
                            Text(event.date.gardenDisplay)
                                .font(CroftTheme.supporting)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var historyScaffold: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
            Text("Along the way")
                .font(.headline)
                .foregroundStyle(.secondary)
            historyRow(
                "eye", "Observations",
                "Notes on how this planting is doing will gather here.")
            historyRow(
                "basket", "Harvests",
                "What you pick from it will be tallied here.")
            historyRow(
                "checklist", "Tasks",
                "Watering, feeding, and pruning reminders will live here.")
        }
    }

    private func historyRow(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: CroftTheme.space(3)) {
            Image(systemName: symbol)
                .font(.system(.body, weight: .light))
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(CroftTheme.space(3))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
    }
}
