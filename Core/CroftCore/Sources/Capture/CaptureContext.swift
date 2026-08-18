import Domain
import Foundation
import Persistence
import PlantCatalog

public struct CaptureContext {
    public let personal: AppDatabase
    public let knowledge: AppDatabase?
    public let photos: PhotoStore
    public let defaults: CaptureDefaults

    public init(
        personal: AppDatabase,
        knowledge: AppDatabase?,
        photos: PhotoStore,
        defaults: CaptureDefaults
    ) {
        self.personal = personal
        self.knowledge = knowledge
        self.photos = photos
        self.defaults = defaults
    }

    public var plantings: PlantingRepository { PlantingRepository(personal) }
    public var observations: ObservationRepository {
        ObservationRepository(personal, photos: photos)
    }
    public var harvests: HarvestRepository { HarvestRepository(personal) }
    public var tasks: GardenTaskRepository { GardenTaskRepository(personal) }
    public var seedLots: SeedLotRepository { SeedLotRepository(personal) }
    public var starterBatches: StarterBatchRepository { StarterBatchRepository(personal) }
    public var structures: GardenStructureRepository { GardenStructureRepository(personal) }

    public var adopter: PlantAdopter {
        PlantAdopter(personal: personal, knowledge: knowledge)
    }

    public var rotationHistory: RotationHistory {
        RotationHistory(knowledge: knowledge ?? personal, personal: personal)
    }

    public func plantChoices() throws -> [PlantListItem] {
        let loader: PlantPageLoader =
            if let knowledge {
                PlantPageLoader(knowledge: knowledge, personal: personal)
            } else {
                PlantPageLoader(personal)
            }
        return try loader.listItems()
    }

    public func harvestableParts(for plantingID: Planting.ID) throws -> [HarvestablePart] {
        guard let planting = try plantings.fetch(id: plantingID) else {
            return []
        }
        let species = SpeciesRepository(personal)
        switch planting.identity {
        case .species(let id):
            return try species.fetch(id: id)?.harvestableParts ?? []
        case .cultivar(let id):
            guard let cultivar = try CultivarRepository(personal).fetch(id: id) else {
                return []
            }
            return try species.fetch(id: cultivar.speciesID)?.harvestableParts ?? []
        }
    }

    public func activeBeds() throws -> [(bed: Bed, gardenName: String)] {
        var found: [(Bed, String)] = []
        let structures = self.structures
        for property in try structures.properties() {
            for garden in try structures.gardens(in: property.id) {
                for bed in try structures.beds(in: .garden(garden.id)) {
                    found.append((bed, garden.name))
                }
                for area in try structures.growingAreas(in: garden.id) {
                    for bed in try structures.beds(in: .growingArea(area.id)) {
                        found.append((bed, "\(garden.name) · \(area.name)"))
                    }
                }
            }
        }
        return found
    }
}

public struct CaptureDefaults {
    private let store: UserDefaults
    private static let bedKey = "capture.lastBed"
    private static let unitKey = "capture.lastHarvestUnit"

    public init(store: UserDefaults = .standard) {
        self.store = store
    }

    public var lastBedID: Bed.ID? {
        get { store.string(forKey: Self.bedKey).map(Bed.ID.init(rawValue:)) }
        nonmutating set { store.set(newValue?.rawValue, forKey: Self.bedKey) }
    }

    public var lastHarvestUnit: HarvestUnitChoice? {
        get { store.string(forKey: Self.unitKey).flatMap(HarvestUnitChoice.init(storageValue:)) }
        nonmutating set { store.set(newValue?.storageValue, forKey: Self.unitKey) }
    }

    public var preferredUnitSystem: UnitSystem {
        get { UnitSystemPreference(store: store).system }
        nonmutating set { UnitSystemPreference(store: store).system = newValue }
    }
}

public enum HarvestUnitChoice: Hashable, Sendable {
    case unit(QuantityUnit)
    case custom

    public var storageValue: String {
        switch self {
        case .unit(let unit): unit.rawValue
        case .custom: "custom"
        }
    }

    public init?(storageValue: String) {
        if storageValue == "custom" {
            self = .custom
        } else if let unit = QuantityUnit(rawValue: storageValue) {
            self = .unit(unit)
        } else {
            return nil
        }
    }

    public static func ordered(preferring system: UnitSystem) -> [HarvestUnitChoice] {
        let preferred = QuantityUnit.allCases.filter { $0.system == system || $0.system == nil }
        let others = QuantityUnit.allCases.filter { $0.system != system && $0.system != nil }
        return (preferred + others).map(HarvestUnitChoice.unit) + [.custom]
    }
}
