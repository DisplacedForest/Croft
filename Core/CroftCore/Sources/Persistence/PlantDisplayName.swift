import Domain
import Foundation

public struct PlantDisplayName: Equatable, Sendable {
    public let title: String
    public let varietal: String?

    public init(title: String, varietal: String? = nil) {
        self.title = title
        self.varietal = varietal
    }

    public var detailName: String {
        varietal ?? title
    }
}

public struct PlantDisplayIndex: Sendable {
    public static let unknownName = "Unknown plant"

    private var speciesTitles: [Species.ID: String] = [:]
    private var cultivarNames: [Cultivar.ID: String] = [:]
    private var cultivarSpecies: [Cultivar.ID: Species.ID] = [:]

    public init(databases: [AppDatabase], locale: Locale = .current) throws {
        for database in databases {
            for one in try SpeciesRepository(database).fetchAll() {
                speciesTitles[one.id] =
                    Self.titled(one.preferredCommonName(for: locale)) ?? one.scientificName
            }
            for one in try CultivarRepository(database).fetchAll() {
                cultivarNames[one.id] = one.name
                cultivarSpecies[one.id] = one.speciesID
            }
        }
    }

    public func display(for identity: PlantIdentity) -> PlantDisplayName {
        switch identity {
        case .species(let id):
            return PlantDisplayName(title: speciesTitles[id] ?? Self.unknownName)
        case .cultivar(let id):
            guard let name = cultivarNames[id] else {
                return PlantDisplayName(title: Self.unknownName)
            }
            guard let speciesID = cultivarSpecies[id], let crop = speciesTitles[speciesID] else {
                return PlantDisplayName(title: name)
            }
            return PlantDisplayName(title: crop, varietal: name)
        }
    }

    private static func titled(_ name: String?) -> String? {
        guard let name, let first = name.first else {
            return name
        }
        return first.uppercased() + name.dropFirst()
    }
}
