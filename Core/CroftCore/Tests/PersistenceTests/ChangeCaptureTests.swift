import Domain
import Foundation
import GRDB
import Testing

@testable import Persistence

struct ChangeCapture {
    let database: AppDatabase
    let log: ChangeLogRepository
    let families: PlantFamilyRepository
    let genera: GenusRepository
    let species: SpeciesRepository
    let cultivars: CultivarRepository
    let structures: GardenStructureRepository
    let family: PlantFamily
    let genus: Genus
    let plant: Species
    let cultivar: Cultivar
    let property: Property
    let garden: Garden
    let bed: Bed

    init(recordingChanges: Bool = true) throws {
        database = try AppDatabase.inMemory(recordingChanges: recordingChanges)
        log = ChangeLogRepository(database)
        families = PlantFamilyRepository(database)
        genera = GenusRepository(database)
        species = SpeciesRepository(database)
        cultivars = CultivarRepository(database)
        structures = GardenStructureRepository(database)

        family = PlantFamily(name: "Solanaceae")
        genus = Genus(familyID: family.id, name: "Solanum")
        plant = Species(genusID: genus.id, scientificName: "Solanum lycopersicum")
        cultivar = Cultivar(speciesID: plant.id, name: "Brandywine")
        try families.insert(family)
        try genera.insert(genus)
        try species.insert(plant)
        try cultivars.insert(cultivar)

        property = Property(name: "Home")
        garden = Garden(name: "Kitchen Garden")
        bed = Bed(name: "Long Bed", kind: .raised)
        try structures.create(property)
        try structures.create(garden, in: property.id)
        try structures.create(bed, in: .garden(garden.id))
    }

    func operations(_ kind: ChangeKind, _ id: String) throws -> [ChangeOperation] {
        try log.changes(for: kind, entityID: id).map(\.operation)
    }

    func expectLifecycle(
        _ kind: ChangeKind,
        _ id: String,
        create: () throws -> Void,
        update: () throws -> Void,
        delete: () throws -> Void
    ) throws {
        let before = try log.count()
        try create()
        #expect(try operations(kind, id) == [.create])
        #expect(try log.count() == before + 1)
        try update()
        #expect(try operations(kind, id) == [.create, .update])
        #expect(try log.count() == before + 2)
        try delete()
        #expect(try operations(kind, id) == [.create, .update, .delete])
        #expect(try log.count() == before + 3)
    }
}

@Test func plantFamilyWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    var added = PlantFamily(name: "Lamiaceae")
    try capture.expectLifecycle(.plantFamily, added.id.rawValue) {
        try capture.families.insert(added)
    } update: {
        added.name = "Mint Family"
        try capture.families.update(added)
    } delete: {
        try capture.families.delete(id: added.id)
    }
}

@Test func genusWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    var added = Genus(familyID: capture.family.id, name: "Capsicum")
    try capture.expectLifecycle(.genus, added.id.rawValue) {
        try capture.genera.insert(added)
    } update: {
        added.name = "Capsicum L."
        try capture.genera.update(added)
    } delete: {
        try capture.genera.delete(id: added.id)
    }
}

@Test func speciesWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    var added = Species(genusID: capture.genus.id, scientificName: "Solanum melongena")
    try capture.expectLifecycle(.species, added.id.rawValue) {
        try capture.species.insert(added)
    } update: {
        added.commonNames = ["Eggplant"]
        try capture.species.update(added)
    } delete: {
        try capture.species.delete(id: added.id)
    }
}

@Test func cultivarWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    var added = Cultivar(speciesID: capture.plant.id, name: "San Marzano")
    try capture.expectLifecycle(.cultivar, added.id.rawValue) {
        try capture.cultivars.insert(added)
    } update: {
        added.name = "San Marzano II"
        try capture.cultivars.update(added)
    } delete: {
        try capture.cultivars.delete(id: added.id)
    }
}

@Test func pestWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    let pests = PestRepository(capture.database)
    var added = Pest(commonName: "Aphid", organismType: .pest)
    try capture.expectLifecycle(.pest, added.id.rawValue) {
        try pests.insert(added)
    } update: {
        added.commonName = "Green Peach Aphid"
        try pests.update(added)
    } delete: {
        try pests.delete(id: added.id)
    }
}

@Test func diseaseWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    let diseases = DiseaseRepository(capture.database)
    var added = Disease(name: "Late Blight", pathogenType: .fungal)
    try capture.expectLifecycle(.disease, added.id.rawValue) {
        try diseases.insert(added)
    } update: {
        added.symptoms = "Water soaked lesions"
        try diseases.update(added)
    } delete: {
        try diseases.delete(id: added.id)
    }
}

@Test func pathogenWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    let pathogens = PathogenRepository(capture.database)
    var added = Pathogen(name: "Phytophthora infestans")
    try capture.expectLifecycle(.pathogen, added.id.rawValue) {
        try pathogens.insert(added)
    } update: {
        added.name = "Phytophthora infestans (Mont.)"
        try pathogens.update(added)
    } delete: {
        try pathogens.delete(id: added.id)
    }
}

@Test func environmentalConditionWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    let conditions = EnvironmentalConditionRepository(capture.database)
    var added = EnvironmentalCondition(name: "Prolonged Leaf Wetness")
    try capture.expectLifecycle(.environmentalCondition, added.id.rawValue) {
        try conditions.insert(added)
    } update: {
        added.name = "Leaf Wetness"
        try conditions.update(added)
    } delete: {
        try conditions.delete(id: added.id)
    }
}

@Test func gardenStructureWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    let added = Garden(name: "Orchard")
    try capture.expectLifecycle(.garden, added.id.rawValue) {
        try capture.structures.create(added, in: capture.property.id)
    } update: {
        try capture.structures.renameGarden(added.id, to: "Old Orchard")
    } delete: {
        try capture.structures.deleteGarden(added.id)
    }
}

@Test func bedWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    let added = Bed(name: "Herb Bed", kind: .container)
    try capture.expectLifecycle(.bed, added.id.rawValue) {
        try capture.structures.create(added, in: .garden(capture.garden.id))
    } update: {
        try capture.structures.setBedArchived(added.id, true)
    } delete: {
        try capture.structures.deleteBed(added.id)
    }
}

@Test func seedingTheFixtureCapturesEveryCreate() throws {
    let capture = try ChangeCapture()
    let kinds = try capture.log.all().map(\.kind)
    #expect(kinds == [.plantFamily, .genus, .species, .cultivar, .property, .garden, .bed])
    #expect(try capture.log.all().allSatisfy { $0.operation == .create })
}
