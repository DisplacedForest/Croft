import Domain
import PlantCatalog
import SwiftUI

struct CropVarietalsView: View {
    @Environment(\.appStores) private var stores
    let speciesID: Species.ID
    let navigate: (SectionRoute) -> Void
    @State private var group: CropGroup?
    @State private var didLoad = false
    @State private var query = ""

    var body: some View {
        Group {
            if let group {
                CropVarietalsList(
                    content: CropPageContent.build(group: group, query: query),
                    group: group,
                    navigate: navigate
                )
                .searchable(text: $query, prompt: "Search varietals")
                .navigationTitle(group.crop.displayName)
            } else if didLoad {
                ContentUnavailableView(
                    "This crop is gone",
                    systemImage: "leaf",
                    description: Text("It may have been removed from the plant library.")
                )
            } else {
                ProgressView()
            }
        }
        .task {
            guard !didLoad, let stores else { return }
            let loader = stores.plantPages
            let speciesID = speciesID
            group = await Task.detached {
                (try? loader.cropCatalog())?.group(for: speciesID)
            }.value
            didLoad = true
        }
    }
}

enum CropVarietalSectionContent: Equatable {
    case rows([PlantListItem])
    case noMatches(query: String)
}

struct CropPageContent: Equatable {
    let cropRow: PlantListItem
    let varietals: CropVarietalSectionContent

    static func build(group: CropGroup, query: String) -> CropPageContent {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = PlantSearch.filter(group.varietals, matching: trimmed)
        let varietals: CropVarietalSectionContent =
            if matched.isEmpty && !trimmed.isEmpty {
                .noMatches(query: trimmed)
            } else {
                .rows(matched)
            }
        return CropPageContent(cropRow: group.crop, varietals: varietals)
    }
}

struct CropVarietalsList: View {
    let content: CropPageContent
    let group: CropGroup
    let navigate: (SectionRoute) -> Void

    var body: some View {
        List {
            Section {
                Button {
                    navigate(.plant(content.cropRow.identity))
                } label: {
                    CropRowView(group: group)
                }
                .buttonStyle(.plain)
            } header: {
                Text("Crop")
            }
            Section("Varietals") {
                switch content.varietals {
                case .rows(let items):
                    ForEach(items) { item in
                        Button {
                            navigate(.plant(item.identity))
                        } label: {
                            VarietalRowView(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                case .noMatches(let query):
                    ContentUnavailableView.search(text: query)
                }
            }
        }
    }
}
