import Domain
import PlantCatalog
import SwiftUI

struct PlantsHomeView: View {
    @Environment(\.appStores) private var stores
    let navigate: (SectionRoute) -> Void
    @State private var items: [PlantListItem] = []
    @State private var query = ""
    @State private var didLoad = false

    private var filtered: [PlantListItem] {
        PlantSearch.filter(items, matching: query)
    }

    var body: some View {
        List(filtered) { item in
            Button {
                navigate(.plant(item.identity))
            } label: {
                PlantRowView(item: item)
            }
            .buttonStyle(.plain)
        }
        .searchable(text: $query, prompt: "Common or scientific name")
        .overlay {
            if items.isEmpty {
                ContentUnavailableView(
                    "No plants yet",
                    systemImage: "leaf",
                    description: Text("The plant library appears here once it is installed.")
                )
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .task {
            guard !didLoad, let stores else { return }
            didLoad = true
            let loader = stores.plantPages
            items = await Task.detached { (try? loader.listItems()) ?? [] }.value
        }
    }
}

private struct PlantRowView: View {
    let item: PlantListItem

    var body: some View {
        VStack(alignment: .leading, spacing: CroftTheme.space(1)) {
            HStack(spacing: CroftTheme.space(2)) {
                Text(item.displayName)
                    .font(.body.weight(.medium))
                if item.kind == .cultivar {
                    Text("Cultivar")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, CroftTheme.space(1.5))
                        .padding(.vertical, CroftTheme.space(0.5))
                        .background(.tint.opacity(0.12), in: Capsule())
                        .foregroundStyle(.tint)
                }
            }
            Text(item.scientificName)
                .font(.callout.italic())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, CroftTheme.space(1))
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
