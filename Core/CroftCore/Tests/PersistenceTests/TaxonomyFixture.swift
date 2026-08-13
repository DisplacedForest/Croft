import Domain
import GRDB
import Testing

@testable import Persistence

struct CorruptibleTaxonomy {
    let database: AppDatabase
    let family: PlantFamily
    let species: Species
    let cultivar: Cultivar

    init() throws {
        database = try AppDatabase.inMemory()
        family = PlantFamily(name: "Solanaceae")
        let genus = Genus(familyID: family.id, name: "Solanum")
        species = Species(genusID: genus.id, scientificName: "Solanum lycopersicum")
        cultivar = Cultivar(speciesID: species.id, name: "San Marzano")
        try PlantFamilyRepository(database).insert(family)
        try GenusRepository(database).insert(genus)
        try SpeciesRepository(database).insert(species)
        try CultivarRepository(database).insert(cultivar)
    }

    func corrupt(table: String, id: String, assignments: String) throws {
        try database.writer.write { db in
            try db.execute(sql: "PRAGMA ignore_check_constraints = ON")
            try db.execute(
                sql: "UPDATE \(table) SET \(assignments) WHERE id = ?",
                arguments: [id]
            )
            try db.execute(sql: "PRAGMA ignore_check_constraints = OFF")
        }
    }

    func corruptSpecies(_ assignments: String) throws {
        try corrupt(table: "species", id: species.id.rawValue, assignments: assignments)
    }

    func corruptCultivar(_ assignments: String) throws {
        try corrupt(table: "cultivar", id: cultivar.id.rawValue, assignments: assignments)
    }

    func corruptFamily(_ assignments: String) throws {
        try corrupt(table: "plant_family", id: family.id.rawValue, assignments: assignments)
    }
}
