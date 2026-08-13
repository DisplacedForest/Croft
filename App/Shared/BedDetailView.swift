import Domain
import GardenModel
import SwiftUI

struct BedDetailView: View {
    @Environment(GardenStore.self) private var store
    @Environment(CaptureStore.self) private var capture
    let bedID: Bed.ID
    let navigate: (SectionRoute) -> Void

    var body: some View {
        let capture = capture
        if let detail = store.bedDetail(bedID) {
            ScrollView {
                VStack(alignment: .leading, spacing: CroftTheme.space(6)) {
                    header(detail)
                    currentSection(detail)
                    if !detail.past.isEmpty {
                        pastSection(detail)
                    }
                }
                .padding(CroftTheme.space(6))
                .frame(maxWidth: 640, alignment: .leading)
            }
            .navigationTitle(detail.bed.name)
            .toolbar {
                Button {
                    capture.present(.addPlanting(bedID))
                } label: {
                    Label("Add Planting", systemImage: "leaf.circle")
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }

            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
        } else {
            ContentUnavailableView(
                "This bed has been put away",
                systemImage: "square.stack.3d.up.slash",
                description: Text("It may have been archived from another window.")
            )
        }
    }

    private func header(_ detail: BedDetail) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
            Text(detail.bed.name)
                .font(CroftTheme.display)
            Label {
                Text("\(detail.bed.kind.displayName) · \(detail.locationName)")
            } icon: {
                Image(systemName: detail.bed.kind.symbolName)
                    .foregroundStyle(.tint)
            }
            .font(CroftTheme.supporting)
            .foregroundStyle(.secondary)
            if let notes = detail.bed.notes, !notes.isEmpty {
                Text(notes)
                    .font(CroftTheme.supporting)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func currentSection(_ detail: BedDetail) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
            Text("Growing now")
                .font(.headline)
                .foregroundStyle(.secondary)
            if detail.current.isEmpty {
                Text("Nothing growing here yet. New plantings will appear as they go in.")
                    .font(CroftTheme.supporting)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(spacing: CroftTheme.space(2)) {
                    ForEach(detail.current) { summary in
                        plantingRow(summary)
                    }
                }
            }
        }
    }

    private func pastSection(_ detail: BedDetail) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
            Text("Previously in this bed")
                .font(.headline)
                .foregroundStyle(.secondary)
            VStack(spacing: CroftTheme.space(2)) {
                ForEach(detail.past) { summary in
                    plantingRow(summary)
                }
            }
        }
    }

    private func plantingRow(_ summary: PlantingSummary) -> some View {
        Button {
            navigate(.planting(summary.planting.id))
        } label: {
            HStack(spacing: CroftTheme.space(3)) {
                Circle()
                    .fill(
                        summary.planting.status == .active
                            ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary)
                    )
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.plantName)
                        .font(.body.weight(.medium))
                    Text(subtitle(summary.planting))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(CroftTheme.space(3))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func subtitle(_ planting: Planting) -> String {
        var parts = [planting.status.displayName]
        if let quantity = planting.quantity {
            parts.append("\(quantity) plants")
        }
        if let planted = planting.plantedOn {
            parts.append("planted \(planted.gardenDisplay)")
        }
        if let ended = planting.endedOn {
            parts.append("ended \(ended.gardenDisplay)")
        }
        return parts.joined(separator: " · ")
    }
}
