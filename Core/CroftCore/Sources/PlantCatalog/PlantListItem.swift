import Domain
import Foundation

public struct PlantListItem: Equatable, Hashable, Sendable, Identifiable {
    public enum Kind: Equatable, Hashable, Sendable {
        case species
        case cultivar
    }

    public var id: String
    public var identity: PlantIdentity
    public var kind: Kind
    public var displayName: String
    public var scientificName: String
    public var otherNames: [String]

    public init(
        id: String,
        identity: PlantIdentity,
        kind: Kind,
        displayName: String,
        scientificName: String,
        otherNames: [String] = []
    ) {
        self.id = id
        self.identity = identity
        self.kind = kind
        self.displayName = displayName
        self.scientificName = scientificName
        self.otherNames = otherNames
    }
}

public enum PlantSearch {
    public static func filter(_ items: [PlantListItem], matching query: String) -> [PlantListItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { item in
            var names = [item.displayName, item.scientificName]
            names.append(contentsOf: item.otherNames)
            return names.contains { name in
                name.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }
}
