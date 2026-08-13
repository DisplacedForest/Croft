import Domain
import Foundation
import Persistence

struct GardenFixture {
    let database: AppDatabase
    let structures: GardenStructureRepository
    let plantings: PlantingRepository
    let species: SpeciesRepository
    let cultivars: CultivarRepository
    let property: Property
    let garden: Garden
    let growingArea: GrowingArea
    let bed: Bed
    let tunnelBed: Bed
    let tomatoSpecies: Species
    let tomatoCultivar: Cultivar

    init() throws {
        database = try AppDatabase.inMemory()
        structures = GardenStructureRepository(database)
        plantings = PlantingRepository(database)
        species = SpeciesRepository(database)
        cultivars = CultivarRepository(database)

        let familyRepository = PlantFamilyRepository(database)
        let genusRepository = GenusRepository(database)
        let family = PlantFamily(name: "Solanaceae")
        let genus = Genus(familyID: family.id, name: "Solanum")
        tomatoSpecies = Species(
            genusID: genus.id,
            scientificName: "Solanum lycopersicum",
            commonNames: ["Tomato"]
        )
        tomatoCultivar = Cultivar(speciesID: tomatoSpecies.id, name: "Brandywine")
        try familyRepository.insert(family)
        try genusRepository.insert(genus)
        try species.insert(tomatoSpecies)
        try cultivars.insert(tomatoCultivar)

        property = Property(name: "Home")
        garden = Garden(name: "Kitchen Garden")
        growingArea = GrowingArea(name: "Polytunnel")
        bed = Bed(name: "Long Bed", kind: .raised)
        tunnelBed = Bed(name: "Tunnel Bed", kind: .inGround)
        try structures.create(property)
        try structures.create(garden, in: property.id)
        try structures.create(growingArea, in: garden.id)
        try structures.create(bed, in: .garden(garden.id))
        try structures.create(tunnelBed, in: .growingArea(growingArea.id))
    }

    @discardableResult
    func addPlanting(
        in bedID: Bed.ID? = nil,
        identity: PlantIdentity? = nil,
        status: PlantingStatus = .active,
        plantedOn: Date? = nil,
        transplantedOn: Date? = nil,
        endedOn: Date? = nil
    ) throws -> Planting {
        let planting = Planting(
            identity: identity ?? .cultivar(tomatoCultivar.id),
            bedID: bedID ?? bed.id,
            plantedOn: plantedOn,
            transplantedOn: transplantedOn,
            status: status,
            endedOn: endedOn
        )
        try plantings.insert(planting)
        return planting
    }
}

let march = Date(timeIntervalSince1970: 1_710_000_000)
let april = Date(timeIntervalSince1970: 1_712_000_000)
let may = Date(timeIntervalSince1970: 1_715_000_000)
let june = Date(timeIntervalSince1970: 1_718_000_000)
