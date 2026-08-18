import Domain
import PlantCatalog
import SwiftUI

struct PlantsHomeView: View {
    @Environment(\.appStores) private var stores
    let navigate: (SectionRoute) -> Void
    @State private var catalog = CropCatalog(crops: [])
    @State private var query = ""
    @State private var didLoad = false

    private var results: CropSearchResults {
        CropSearch.filter(catalog, matching: query)
    }

    private var searching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group {
            if searching {
                searchResults
            } else {
                cropGrid
            }
        }
        .searchable(text: $query, prompt: "Crop, varietal, or scientific name")
        .overlay {
            if catalog.isEmpty {
                ContentUnavailableView(
                    "No plants yet",
                    systemImage: "leaf",
                    description: Text("The plant library appears here once it is installed.")
                )
            } else if searching && results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .task {
            guard !didLoad, let stores else { return }
            didLoad = true
            let loader = stores.plantPages
            catalog = await Task.detached { (try? loader.cropCatalog()) ?? CropCatalog(crops: []) }
                .value
        }
    }

    private var cropGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 180, maximum: 240), spacing: CroftTheme.space(4))
                ],
                spacing: CroftTheme.space(4)
            ) {
                ForEach(catalog.crops) { group in
                    CropCardView(group: group) {
                        open(group)
                    }
                }
            }
            .padding(CroftTheme.space(6))
        }
    }

    private var searchResults: some View {
        List {
            if !results.crops.isEmpty {
                Section("Crops") {
                    ForEach(results.crops) { group in
                        Button {
                            open(group)
                        } label: {
                            CropRowView(group: group)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !results.varietals.isEmpty {
                Section("Varietals") {
                    ForEach(results.varietals) { item in
                        Button {
                            navigate(.plant(item.identity))
                        } label: {
                            VarietalRowView(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func open(_ group: CropGroup) {
        if group.varietals.isEmpty {
            navigate(.plant(group.crop.identity))
        } else if let speciesID = group.speciesID {
            navigate(.crop(speciesID))
        } else {
            navigate(.plant(group.crop.identity))
        }
    }
}

struct CropCardView: View {
    let group: CropGroup
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: CroftTheme.space(2)) {
                PlantImageView(file: group.crop.imageFile, cornerRadius: CroftTheme.space(2))
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                Text(group.crop.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(group.crop.scientificName)
                    .font(.caption.italic())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(varietalLine)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(CroftTheme.space(4))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var varietalLine: String {
        switch group.varietalCount {
        case 0: "Detail page"
        case 1: "1 varietal"
        default: "\(group.varietalCount) varietals"
        }
    }
}

struct CropRowView: View {
    let group: CropGroup

    var body: some View {
        HStack(spacing: CroftTheme.space(3)) {
            PlantImageView(file: group.crop.imageFile, cornerRadius: CroftTheme.space(2))
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: CroftTheme.space(1)) {
                Text(group.crop.displayName)
                    .font(.body.weight(.medium))
                Text(group.crop.scientificName)
                    .font(.callout.italic())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if group.varietalCount > 0 {
                Text("\(group.varietalCount)")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, CroftTheme.space(2))
                    .padding(.vertical, CroftTheme.space(0.5))
                    .background(.tint.opacity(0.12), in: Capsule())
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, CroftTheme.space(1))
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct VarietalRowView: View {
    let item: PlantListItem

    var body: some View {
        HStack(spacing: CroftTheme.space(3)) {
            PlantImageView(file: item.imageFile, cornerRadius: CroftTheme.space(2))
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: CroftTheme.space(1)) {
                HStack(spacing: CroftTheme.space(2)) {
                    Text(item.displayName)
                        .font(.body.weight(.medium))
                    Text("Varietal")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, CroftTheme.space(1.5))
                        .padding(.vertical, CroftTheme.space(0.5))
                        .background(.tint.opacity(0.12), in: Capsule())
                        .foregroundStyle(.tint)
                }
                Text(item.scientificName)
                    .font(.callout.italic())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, CroftTheme.space(1))
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
