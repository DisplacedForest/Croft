import Foundation

import enum Domain.PlantIdentity
import struct Domain.Species

public struct CropGroup: Equatable, Hashable, Sendable, Identifiable {
    public let crop: PlantListItem
    public let varietals: [PlantListItem]

    public var id: String { crop.id }
    public var varietalCount: Int { varietals.count }

    public var speciesID: Species.ID? {
        if case .species(let id) = crop.identity {
            return id
        }
        return nil
    }

    public init(crop: PlantListItem, varietals: [PlantListItem]) {
        self.crop = crop
        self.varietals = varietals
    }
}

public struct CropCatalog: Equatable, Sendable {
    public let crops: [CropGroup]

    public init(crops: [CropGroup]) {
        self.crops = crops
    }

    public var isEmpty: Bool { crops.isEmpty }

    public func group(for speciesID: Species.ID) -> CropGroup? {
        crops.first { $0.speciesID == speciesID }
    }
}

public struct CropSearchResults: Equatable, Sendable {
    public let crops: [CropGroup]
    public let varietals: [PlantListItem]

    public var isEmpty: Bool { crops.isEmpty && varietals.isEmpty }
}

public enum CropSearch {
    public static func filter(_ catalog: CropCatalog, matching query: String) -> CropSearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return CropSearchResults(crops: catalog.crops, varietals: [])
        }
        let crops = catalog.crops.filter { matches($0.crop, trimmed) }
        let varietals = catalog.crops
            .flatMap(\.varietals)
            .filter { matches($0, trimmed) }
        return CropSearchResults(crops: crops, varietals: varietals)
    }

    private static func matches(_ item: PlantListItem, _ query: String) -> Bool {
        var names = [item.displayName, item.scientificName]
        names.append(contentsOf: item.otherNames)
        return names.contains { name in
            name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
