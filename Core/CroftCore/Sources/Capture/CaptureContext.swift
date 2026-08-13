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

    public func plantChoices() throws -> [PlantListItem] {
        let loader: PlantPageLoader =
            if let knowledge {
                PlantPageLoader(knowledge: knowledge, personal: personal)
            } else {
                PlantPageLoader(personal)
            }
        return try loader.listItems()
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

    public var lastHarvestUnit: HarvestUnit? {
        get { store.string(forKey: Self.unitKey).flatMap(HarvestUnit.init(rawValue:)) }
        nonmutating set { store.set(newValue?.rawValue, forKey: Self.unitKey) }
    }
}
