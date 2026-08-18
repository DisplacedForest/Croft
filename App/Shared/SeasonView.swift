import Design
import Domain
import Foundation
import PlantCatalog
import SwiftUI

struct SeasonView: View {
    @Environment(\.appStores) private var stores
    @Environment(CaptureStore.self) private var capture
    @State private var overview: SeasonOverview?
    @State private var unavailable = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CroftTheme.space(6)) {
                if let overview {
                    sowingArea(overview)
                    yearArea(overview)
                } else if unavailable {
                    Text("Season data is unavailable.")
                        .font(CroftTheme.supporting)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .padding(CroftTheme.space(6))
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Season")
        .task { load() }
        .onChange(of: capture.saveCount) { _, _ in
            load()
        }
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private func sowingArea(_ overview: SeasonOverview) -> some View {
        if !overview.hasFrostDates {
            frostNotice
        } else if overview.plantableNow.isEmpty && overview.upcoming.isEmpty {
            Text("Nothing to sow right now.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            if !overview.plantableNow.isEmpty {
                section("Plantable now") {
                    ForEach(overview.plantableNow) { entry in
                        entryRow(entry)
                    }
                    if !overview.unassessed.isEmpty {
                        Text(unassessedNote(overview.unassessed.count))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            if !overview.upcoming.isEmpty {
                section("Coming up") {
                    ForEach(overview.upcoming) { entry in
                        entryRow(entry)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func yearArea(_ overview: SeasonOverview) -> some View {
        if overview.planned.isEmpty && overview.inGround.isEmpty && overview.finished.isEmpty {
            Text("Nothing planned or growing yet.")
                .font(CroftTheme.supporting)
                .foregroundStyle(.secondary)
        } else {
            if !overview.planned.isEmpty {
                section("Planned") {
                    ForEach(overview.planned) { item in
                        plantingRow(item)
                    }
                }
            }
            if !overview.inGround.isEmpty {
                section("In the ground") {
                    ForEach(overview.inGround) { item in
                        plantingRow(item)
                    }
                }
            }
            if !overview.finished.isEmpty {
                section("Finished this year") {
                    ForEach(overview.finished) { item in
                        plantingRow(item)
                    }
                }
            }
        }
    }

    private var frostNotice: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
            Text("Add your frost dates to see planting windows.")
                .font(CroftTheme.supporting)
            Text("Set them in the property settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(CroftTheme.space(4))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.domainGarden.opacity(0.12),
            in: RoundedRectangle(cornerRadius: CroftTheme.space(3))
        )
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            VStack(spacing: CroftTheme.space(2)) {
                content()
            }
        }
    }

    private func entryRow(_ entry: SeasonEntry) -> some View {
        Button {
            capture.present(
                .addPlanting(AddPlantingIntent(identity: entry.identity, planned: true)))
        } label: {
            row(title: entry.displayName, subtitle: reason(entry), showsChevron: true)
        }
        .buttonStyle(.plain)
    }

    private func plantingRow(_ item: SeasonPlanting) -> some View {
        row(title: item.plantName, subtitle: plantingSubtitle(item), showsChevron: false)
    }

    private func row(title: String, subtitle: String?, showsChevron: Bool) -> some View {
        HStack(spacing: CroftTheme.space(3)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(CroftTheme.space(3))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }

    private func reason(_ entry: SeasonEntry) -> String {
        var parts: [String] = []
        switch entry.assessment {
        case .act(let opportunity):
            parts.append(
                "\(actionPhrase(opportunity.action)) until "
                    + opportunity.window.upperBound.gardenDisplay)
        case .upcoming(let opportunity):
            parts.append("From \(opportunity.window.lowerBound.gardenDisplay)")
        case .notApplicable, .cannotAssess:
            break
        }
        if let tolerance = entry.profile.frostTolerance {
            parts.append(tolerancePhrase(tolerance))
        }
        var line = parts.joined(separator: ", ")
        if let minimum = entry.profile.germinationTempMin {
            line += " · soil at least \(Int(minimum.rounded()))°C"
        }
        return line
    }

    private func actionPhrase(_ action: SowingAction) -> String {
        switch action {
        case .sowIndoors: "Start indoors"
        case .directSow: "Direct sow"
        case .transplantOut: "Transplant out"
        }
    }

    private func tolerancePhrase(_ tolerance: FrostTolerance) -> String {
        switch tolerance {
        case .hardy: "hardy"
        case .halfHardy: "half hardy"
        case .tender: "tender"
        }
    }

    private func unassessedNote(_ count: Int) -> String {
        count == 1
            ? "1 plant needs more profile data to assess."
            : "\(count) plants need more profile data to assess."
    }

    private func plantingSubtitle(_ item: SeasonPlanting) -> String {
        var parts: [String] = []
        if let location = item.locationName {
            parts.append(location)
        }
        if let planted = item.planting.plantedOn {
            parts.append("planted \(planted.gardenDisplay)")
        }
        if let ended = item.planting.endedOn {
            parts.append("ended \(ended.gardenDisplay)")
        }
        return parts.joined(separator: " · ")
    }

    private func load() {
        guard let stores else {
            unavailable = true
            return
        }
        let planner =
            if let knowledge = stores.knowledgeDatabase {
                SeasonPlanner(knowledge: knowledge, personal: stores.database)
            } else {
                SeasonPlanner(stores.database)
            }
        overview = try? planner.overview(on: Date(), calendar: Calendar.current)
        unavailable = overview == nil
    }
}
