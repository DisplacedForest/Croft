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

    private var filteredVarietals: [PlantListItem] {
        PlantSearch.filter(group?.varietals ?? [], matching: query)
    }

    private var searching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group {
            if let group {
                List {
                    Section {
                        Button {
                            navigate(.plant(group.crop.identity))
                        } label: {
                            CropRowView(group: group)
                        }
                        .buttonStyle(.plain)
                    } header: {
                        Text("Crop")
                    }
                    Section("Varietals") {
                        ForEach(filteredVarietals) { item in
                            Button {
                                navigate(.plant(item.identity))
                            } label: {
                                VarietalRowView(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .searchable(text: $query, prompt: "Search varietals")
                .overlay {
                    if searching && filteredVarietals.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
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
