import Design
import Domain
import PlantCatalog
import SwiftUI

struct PlantPageView: View {
    @Environment(\.appStores) private var stores
    let identity: PlantIdentity
    @State private var page: PlantPage?
    @State private var didLoad = false

    var body: some View {
        Group {
            if let page {
                PlantPageContent(page: page)
            } else {
                ContentUnavailableView(
                    "Plant unavailable",
                    systemImage: "leaf",
                    description: Text("This plant could not be loaded.")
                )
            }
        }
        .task {
            guard !didLoad, let stores else { return }
            didLoad = true
            let loader = stores.plantPages
            let identity = identity
            page = await Task.detached { try? loader.page(for: identity) }.value
        }
    }
}

private struct PlantPageContent: View {
    let page: PlantPage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CroftTheme.space(8)) {
                header
                conditionsSection
                threatsSection
                plantingsSection
                activitySection
            }
            .padding(CroftTheme.space(6))
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(page.displayName)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(4)) {
            PlantHeaderImage(image: page.image)
            headerText
        }
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
            Text(page.displayName)
                .font(CroftTheme.display)
            Text(scientificLine)
                .font(CroftTheme.supporting.italic())
                .foregroundStyle(.secondary)
            if !taxonomyLine.isEmpty {
                Text(taxonomyLine)
                    .font(CroftTheme.supporting)
                    .foregroundStyle(.secondary)
            }
            if !otherNames.isEmpty {
                Text("Also known as \(otherNames.joined(separator: ", "))")
                    .font(CroftTheme.supporting)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var scientificLine: String {
        if let cultivarName = page.taxonomy.cultivarName {
            "\(page.taxonomy.scientificName) '\(cultivarName)'"
        } else {
            page.taxonomy.scientificName
        }
    }

    private var taxonomyLine: String {
        [page.taxonomy.familyName, page.taxonomy.genusName]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var otherNames: [String] {
        page.commonNames.filter { $0.caseInsensitiveCompare(page.displayName) != .orderedSame }
    }

    private var conditionsSection: some View {
        PlantPageSection(title: "Growing conditions") {
            let rows = conditionRows
            if rows.isEmpty {
                PlantPageEmptyRow(text: "No growing guidance recorded.")
            } else {
                VStack(spacing: 0) {
                    ForEach(rows, id: \.label) { row in
                        ConditionRow(row: row)
                        if row.label != rows.last?.label {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var conditionRows: [ConditionRowModel] {
        var rows: [ConditionRowModel] = []
        let conditions = page.conditions
        if let sun = conditions.sunExposure {
            rows.append(ConditionRowModel(label: "Sun", value: sun.displayName))
        }
        if let water = conditions.waterNeed {
            rows.append(ConditionRowModel(label: "Water", value: water.displayName))
        }
        if let soilPH = conditions.soilPH {
            rows.append(ConditionRowModel(label: "Soil", value: ConditionText.soilPH(soilPH)))
        }
        if let spacing = conditions.spacingCentimeters {
            rows.append(
                ConditionRowModel(
                    label: "Spacing",
                    value: ConditionText.centimeters(spacing.value),
                    isCultivarOverride: spacing.isCultivarOverride))
        }
        if let days = conditions.daysToMaturity {
            rows.append(
                ConditionRowModel(
                    label: "Days to maturity",
                    value: ConditionText.days(days.value),
                    isCultivarOverride: days.isCultivarOverride))
        }
        if let habit = conditions.growthHabit {
            rows.append(
                ConditionRowModel(
                    label: "Habit",
                    value: habit.value.displayName,
                    isCultivarOverride: habit.isCultivarOverride))
        }
        if let lifeCycle = conditions.lifeCycle {
            rows.append(ConditionRowModel(label: "Life cycle", value: lifeCycle.displayName))
        }
        if let frost = conditions.frostTolerance {
            rows.append(ConditionRowModel(label: "Frost", value: frost.displayName))
        }
        if !conditions.harvestableParts.isEmpty {
            rows.append(
                ConditionRowModel(
                    label: "Harvest",
                    value: conditions.harvestableParts.map(\.displayName)
                        .joined(separator: ", ")))
        }
        return rows
    }

    private var threatsSection: some View {
        PlantPageSection(title: "Common threats") {
            if page.threats.isEmpty {
                PlantPageEmptyRow(text: "No known pests or diseases recorded.")
            } else {
                VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
                    ForEach(page.threats) { threat in
                        ThreatRow(threat: threat)
                    }
                }
            }
        }
    }

    private var plantingsSection: some View {
        PlantPageSection(title: "Growing now") {
            if page.currentPlantings.isEmpty {
                PlantPageEmptyRow(text: "Not planted right now.")
            } else {
                VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
                    ForEach(page.currentPlantings) { planting in
                        PlantingRow(planting: planting)
                    }
                }
            }
        }
    }

    private var activitySection: some View {
        PlantPageSection(title: "Recent activity") {
            if page.activity.isEmpty {
                PlantPageEmptyRow(text: "Nothing recorded yet.")
            } else {
                VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
                    ForEach(page.activity) { event in
                        ActivityRow(event: event)
                    }
                }
            }
        }
    }
}

private struct ConditionRowModel {
    let label: String
    let value: String
    var isCultivarOverride = false
}

private struct PlantPageSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
            Text(title)
                .font(CroftTheme.heading)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PlantPageEmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(CroftTheme.supporting)
            .foregroundStyle(.secondary)
    }
}

private struct ConditionRow: View {
    let row: ConditionRowModel

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(row.label)
                .font(CroftTheme.supporting)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: CroftTheme.space(2)) {
                Text(row.value)
                    .font(.body)
                if row.isCultivarOverride {
                    Text("This cultivar")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, CroftTheme.space(1.5))
                        .padding(.vertical, CroftTheme.space(0.5))
                        .background(.tint.opacity(0.12), in: Capsule())
                        .foregroundStyle(.tint)
                }
            }
        }
        .padding(.vertical, CroftTheme.space(2))
    }
}

private struct ThreatRow: View {
    let threat: PlantThreat

    var body: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(1)) {
            HStack(spacing: CroftTheme.space(2)) {
                Text(threat.name)
                    .font(.body.weight(.medium))
                Text(threat.kind.displayName)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, CroftTheme.space(1.5))
                    .padding(.vertical, CroftTheme.space(0.5))
                    .background(Color.domainHealth.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.domainHealth)
            }
            if let agentName = threat.agentName {
                Text(agentName)
                    .font(.callout.italic())
                    .foregroundStyle(.secondary)
            }
            if let summary = threat.summary {
                Text(summary)
                    .font(CroftTheme.supporting)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PlantingRow: View {
    let planting: CurrentPlanting

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: CroftTheme.space(0.5)) {
                Text(planting.locationName ?? "Unknown spot")
                    .font(.body.weight(.medium))
                if let quantity = planting.quantity {
                    Text("\(quantity) plants")
                        .font(CroftTheme.supporting)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(planting.status.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ActivityRow: View {
    let event: ActivityEvent

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: CroftTheme.space(0.5)) {
                Text(activityLine)
                    .font(.body)
                if let location = event.locationName {
                    Text(location)
                        .font(CroftTheme.supporting)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(event.date.formatted(date: .abbreviated, time: .omitted))
                .font(CroftTheme.supporting)
                .foregroundStyle(.secondary)
        }
    }

    private var activityLine: String {
        if let quantity = event.quantity, event.kind == .planted {
            "\(event.kind.displayName) \(quantity)"
        } else {
            event.kind.displayName
        }
    }
}
