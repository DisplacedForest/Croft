import Domain
import Foundation
import Persistence
import Testing

@testable import Capture

struct CaptureFixture {
    let context: CaptureContext
    let bed: Bed
    let secondBed: Bed
    let cultivar: Cultivar
    let species: Species

    init(knowledge: AppDatabase? = nil, brokenPhotoStore: Bool = false) throws {
        let personal = try AppDatabase.inMemory()
        var photoBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("capture-photos-\(UUID().uuidString)", isDirectory: true)
        if brokenPhotoStore {
            let blocker = FileManager.default.temporaryDirectory
                .appendingPathComponent("capture-blocker-\(UUID().uuidString)")
            try Data().write(to: blocker)
            photoBase = blocker.appendingPathComponent("nested", isDirectory: true)
        }
        let suite = UserDefaults(suiteName: "capture-tests-\(UUID().uuidString)")!
        context = CaptureContext(
            personal: personal,
            knowledge: knowledge,
            photos: PhotoStore(baseURL: photoBase),
            defaults: CaptureDefaults(store: suite)
        )

        let structures = GardenStructureRepository(personal)
        let property = Property(name: "Home")
        let garden = Garden(name: "Kitchen Garden")
        bed = Bed(name: "Long Bed", kind: .raised)
        secondBed = Bed(name: "Tunnel Bed", kind: .inGround)
        try structures.create(property)
        try structures.create(garden, in: property.id)
        try structures.create(bed, in: .garden(garden.id))
        try structures.create(secondBed, in: .garden(garden.id))

        let family = PlantFamily(name: "Solanaceae")
        let genus = Genus(familyID: family.id, name: "Solanum")
        species = Species(genusID: genus.id, scientificName: "Solanum lycopersicum")
        cultivar = Cultivar(speciesID: species.id, name: "Brandywine")
        try PlantFamilyRepository(personal).insert(family)
        try GenusRepository(personal).insert(genus)
        try SpeciesRepository(personal).insert(species)
        try CultivarRepository(personal).insert(cultivar)
    }

    static func knowledgeDatabase() throws -> (AppDatabase, Cultivar) {
        let knowledge = try AppDatabase.inMemory()
        let family = PlantFamily(
            id: PlantFamily.ID(rawValue: "family:asteraceae"), name: "Asteraceae")
        let genus = Genus(
            id: Genus.ID(rawValue: "genus:lactuca"), familyID: family.id, name: "Lactuca")
        let species = Species(
            id: Species.ID(rawValue: "species:lactuca-sativa"),
            genusID: genus.id,
            scientificName: "Lactuca sativa"
        )
        let cultivar = Cultivar(
            id: Cultivar.ID(rawValue: "cultivar:lactuca-sativa/little-gem"),
            speciesID: species.id,
            name: "Little Gem"
        )
        try PlantFamilyRepository(knowledge).insert(family)
        try GenusRepository(knowledge).insert(genus)
        try SpeciesRepository(knowledge).insert(species)
        try CultivarRepository(knowledge).insert(cultivar)
        return (knowledge, cultivar)
    }
}
