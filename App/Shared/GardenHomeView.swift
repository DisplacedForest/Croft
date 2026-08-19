import Design
import Domain
import GardenModel
import Persistence
import SwiftUI

enum GardenSheet: Identifiable, Hashable {
    case newGarden
    case newArea(Garden.ID)
    case newBed(BedParent)
    case renameGarden(Garden.ID, String)
    case renameArea(GrowingArea.ID, String)
    case renameBed(Bed.ID, String)

    var id: Self { self }
}

struct GardenHomeView: View {
    @Environment(GardenStore.self) private var store
    let navigate: (SectionRoute) -> Void
    @State private var sheet: GardenSheet?

    var body: some View {
        let gardens = store.overview?.gardens ?? []
        Group {
            if let message = store.startupError {
                ContentUnavailableView(
                    "The garden is out of reach",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            } else if let overview = store.overview {
                if overview.isEmpty {
                    GardenEmptyStateView { sheet = .newGarden }
                } else {
                    overviewList(overview)
                }
            } else {
                ProgressView()
            }
        }
        .toolbar {
            GardenAddMenu(gardens: gardens) { sheet = $0 }
        }
        .sheet(item: $sheet) { sheet in
            sheetView(sheet)
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { store.actionError != nil },
                set: { if !$0 { store.actionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.actionError ?? "")
        }
        .onAppear { store.refresh() }
    }

    private func overviewList(_ overview: GardenOverview) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CroftTheme.space(8)) {
                seasonEntry
                ForEach(overview.gardens) { group in
                    gardenSection(group)
                }
            }
            .padding(CroftTheme.space(6))
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var seasonEntry: some View {
        Button {
            navigate(.season)
        } label: {
            HStack(spacing: CroftTheme.space(3)) {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundStyle(Color.domainGarden)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Season")
                        .font(.body.weight(.medium))
                    Text("Planting windows and the year at a glance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(CroftTheme.space(4))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.domainGarden.opacity(0.12),
                in: RoundedRectangle(cornerRadius: CroftTheme.space(3))
            )
            .contentShape(RoundedRectangle(cornerRadius: CroftTheme.space(3)))
        }
        .buttonStyle(.plain)
    }

    private func gardenSection(_ group: GardenGroup) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(4)) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.garden.name)
                    .font(CroftTheme.heading)
                Spacer()
                Menu {
                    Button("Rename") {
                        sheet = .renameGarden(group.garden.id, group.garden.name)
                    }
                    Button("New Bed") { sheet = .newBed(.garden(group.garden.id)) }
                    Button("New Growing Area") { sheet = .newArea(group.garden.id) }
                    Divider()
                    Button("Archive Garden", role: .destructive) {
                        store.archiveGarden(group.garden.id)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            if group.beds.isEmpty && group.areas.isEmpty {
                emptyGardenHint(group.garden.id)
            } else {
                bedGrid(group.beds, parent: .garden(group.garden.id))
                ForEach(group.areas) { area in
                    areaSection(area, gardens: overviewGardens)
                }
            }
        }
    }

    private var overviewGardens: [GardenGroup] {
        store.overview?.gardens ?? []
    }

    private func areaSection(_ area: GrowingAreaGroup, gardens: [GardenGroup]) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
            HStack(alignment: .firstTextBaseline) {
                Label(area.area.name, systemImage: "cloud.sun")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("Rename") { sheet = .renameArea(area.area.id, area.area.name) }
                    Button("New Bed") { sheet = .newBed(.growingArea(area.area.id)) }
                    if gardens.count > 1 {
                        Menu("Move To") {
                            ForEach(gardens) { destination in
                                Button(destination.garden.name) {
                                    store.moveGrowingArea(
                                        area.area.id, to: destination.garden.id)
                                }
                            }
                        }
                    }
                    Divider()
                    Button("Archive Growing Area", role: .destructive) {
                        store.archiveGrowingArea(area.area.id)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.top, CroftTheme.space(2))
            if area.beds.isEmpty {
                Button("Add a bed") { sheet = .newBed(.growingArea(area.area.id)) }
                    .buttonStyle(.bordered)
            } else {
                bedGrid(area.beds, parent: .growingArea(area.area.id))
            }
        }
    }

    private func bedGrid(_ beds: [BedSummary], parent: BedParent) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 230, maximum: 320), spacing: CroftTheme.space(4))
            ],
            alignment: .leading,
            spacing: CroftTheme.space(4)
        ) {
            ForEach(beds) { summary in
                BedCardView(summary: summary) {
                    navigate(.bed(summary.bed.id))
                } menu: {
                    bedMenu(summary.bed, parent: parent)
                }
            }
        }
    }

    @ViewBuilder
    private func bedMenu(_ bed: Bed, parent: BedParent) -> some View {
        Button("Rename") { sheet = .renameBed(bed.id, bed.name) }
        Menu("Move To") {
            ForEach(overviewGardens) { group in
                if parent != .garden(group.garden.id) {
                    Button(group.garden.name) {
                        store.moveBed(bed.id, to: .garden(group.garden.id))
                    }
                }
                ForEach(group.areas) { area in
                    if parent != .growingArea(area.area.id) {
                        Button("\(area.area.name), \(group.garden.name)") {
                            store.moveBed(bed.id, to: .growingArea(area.area.id))
                        }
                    }
                }
            }
        }
        Divider()
        Button("Archive Bed", role: .destructive) { store.archiveBed(bed.id) }
    }

    private func emptyGardenHint(_ gardenID: Garden.ID) -> some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(3)) {
            Text("Nothing planted here yet. Beds and containers give plantings a home.")
                .font(CroftTheme.supporting)
                .foregroundStyle(.secondary)
            Button("Add a bed") { sheet = .newBed(.garden(gardenID)) }
                .buttonStyle(.bordered)
        }
        .padding(CroftTheme.space(4))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func sheetView(_ sheet: GardenSheet) -> some View {
        switch sheet {
        case .newGarden:
            NameEntrySheet(
                title: "New Garden",
                prompt: "Back Garden, Allotment, Balcony…",
                confirm: "Create"
            ) { store.addGarden(named: $0) }
        case .newArea(let gardenID):
            NameEntrySheet(
                title: "New Growing Area",
                prompt: "Polytunnel, Greenhouse, South Wall…",
                confirm: "Create"
            ) { store.addGrowingArea(named: $0, in: gardenID) }
        case .newBed(let parent):
            NewBedSheet { name, kind in
                store.addBed(named: name, kind: kind, in: parent)
            }
        case .renameGarden(let id, let current):
            NameEntrySheet(title: "Rename Garden", initialName: current, confirm: "Rename") {
                store.renameGarden(id, to: $0)
            }
        case .renameArea(let id, let current):
            NameEntrySheet(
                title: "Rename Growing Area", initialName: current, confirm: "Rename"
            ) {
                store.renameGrowingArea(id, to: $0)
            }
        case .renameBed(let id, let current):
            NameEntrySheet(title: "Rename Bed", initialName: current, confirm: "Rename") {
                store.renameBed(id, to: $0)
            }
        }
    }
}

struct GardenAddMenu: View {
    let gardens: [GardenGroup]
    let choose: (GardenSheet) -> Void

    var body: some View {
        Menu {
            Button("New Garden") { choose(.newGarden) }
            ForEach(gardens) { group in
                Menu(group.garden.name) {
                    Button("New Bed") { choose(.newBed(.garden(group.garden.id))) }
                    Button("New Growing Area") { choose(.newArea(group.garden.id)) }
                }
            }
        } label: {
            Label("Add", systemImage: "plus")
        }
    }
}

struct GardenEmptyStateView: View {
    let createGarden: () -> Void

    var body: some View {
        VStack(spacing: CroftTheme.space(4)) {
            Image(systemName: "tree")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tint)
                .padding(CroftTheme.space(6))
                .background(.tint.opacity(0.12), in: Circle())
            Text("Where your garden takes root.")
                .font(CroftTheme.heading)
                .multilineTextAlignment(.center)
            Text(
                "Croft starts with a garden: a place you grow, and the beds and "
                    + "containers inside it. Plantings, observations, and harvests follow."
            )
            .font(CroftTheme.supporting)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 340)
            Button("Create your first garden") {
                createGarden()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, CroftTheme.space(4))
        }
        .padding(CroftTheme.space(8))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
