import Domain
import GRDB
import Testing

@testable import Persistence

private let taxonomyIdentifier = "v003-taxonomy"

private struct SeededTaxonomy {
    let database: AppDatabase
    let genus: Genus
    let species: Species

    init() throws {
        database = try AppDatabase.inMemory()
        let family = PlantFamily(name: "Solanaceae")
        genus = Genus(familyID: family.id, name: "Solanum")
        species = Species(genusID: genus.id, scientificName: "Solanum lycopersicum")
        try PlantFamilyRepository(database).insert(family)
        try GenusRepository(database).insert(genus)
    }
}

private func speciesRow(_ database: AppDatabase, id: Species.ID) throws -> Row {
    let row = try database.writer.read { db in
        try Row.fetchOne(db, sql: "SELECT * FROM species WHERE id = ?", arguments: [id.rawValue])
    }
    return try #require(row)
}

struct TaxonomyAttributeStorageTests {
    @Test func absentOptionalsAreStoredAsNull() throws {
        let seed = try SeededTaxonomy()
        let database = seed.database
        let species = seed.species
        try SpeciesRepository(database).insert(species)
        let row = try speciesRow(database, id: species.id)
        let columns = [
            "life_cycle", "growth_habit", "sun_exposure", "water_need",
            "soil_ph_min", "soil_ph_max", "spacing_cm_min", "spacing_cm_max",
            "days_to_maturity_min", "days_to_maturity_max",
            "hardiness_zone_min", "hardiness_zone_max",
        ]
        for column in columns {
            #expect(row[column] == DatabaseValue.null)
        }
        let fetched = try #require(try SpeciesRepository(database).fetch(id: species.id))
        #expect(fetched == species)
        #expect(fetched.lifeCycle == nil)
        #expect(fetched.soilPH == nil)
        #expect(fetched.hardinessZones == nil)
    }

    @Test func listsAreStoredAsJSONText() throws {
        let seed = try SeededTaxonomy()
        let database = seed.database
        let base = seed.species
        var species = base
        species.commonNames = ["tomato", "love apple"]
        species.harvestableParts = [.fruit, .seed]
        try SpeciesRepository(database).insert(species)
        let row = try speciesRow(database, id: species.id)
        #expect(row["common_names"] == "[\"tomato\",\"love apple\"]")
        #expect(row["harvestable_parts"] == "[\"fruit\",\"seed\"]")
        let fetched = try #require(try SpeciesRepository(database).fetch(id: species.id))
        #expect(fetched.commonNames == ["tomato", "love apple"])
        #expect(fetched.harvestableParts == [.fruit, .seed])
    }

    @Test func rangesAreStoredAsBoundColumns() throws {
        let seed = try SeededTaxonomy()
        let database = seed.database
        let base = seed.species
        var species = base
        species.soilPH = 6.0...6.8
        species.spacingCentimeters = 45.0...60.0
        species.daysToMaturity = 60...85
        species.hardinessZones = 2...11
        try SpeciesRepository(database).insert(species)
        let row = try speciesRow(database, id: species.id)
        #expect(row["soil_ph_min"] == 6.0)
        #expect(row["soil_ph_max"] == 6.8)
        #expect(row["spacing_cm_min"] == 45.0)
        #expect(row["days_to_maturity_max"] == 85)
        #expect(row["hardiness_zone_min"] == 2)
        let fetched = try #require(try SpeciesRepository(database).fetch(id: species.id))
        #expect(fetched.soilPH == 6.0...6.8)
        #expect(fetched.spacingCentimeters == 45.0...60.0)
        #expect(fetched.daysToMaturity == 60...85)
        #expect(fetched.hardinessZones == 2...11)
    }

    @Test func invertedSpeciesRangeIsRejected() throws {
        let seed = try SeededTaxonomy()
        let database = seed.database
        let genus = seed.genus
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO species (
                            id, genus_id, scientific_name,
                            days_to_maturity_min, days_to_maturity_max
                        )
                        VALUES ('inverted', ?, 'Solanum inversum', 90, 30)
                        """,
                    arguments: [genus.id.rawValue]
                )
            }
        }
    }

    @Test func halfPopulatedSpeciesRangeIsRejected() throws {
        let seed = try SeededTaxonomy()
        let database = seed.database
        let genus = seed.genus
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO species (id, genus_id, scientific_name, soil_ph_min)
                        VALUES ('half', ?, 'Solanum partiale', 6.0)
                        """,
                    arguments: [genus.id.rawValue]
                )
            }
        }
    }

    @Test func invertedCultivarRangeIsRejected() throws {
        let seed = try SeededTaxonomy()
        let database = seed.database
        let species = seed.species
        try SpeciesRepository(database).insert(species)
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO cultivar (
                            id, species_id, name, spacing_cm_min, spacing_cm_max
                        )
                        VALUES ('inverted', ?, 'Inverted', 90.0, 30.0)
                        """,
                    arguments: [species.id.rawValue]
                )
            }
        }
    }
}

struct TaxonomyMigrationTests {
    @Test func dataSeededBeforeTaxonomySurvivesMigrationToHead() throws {
        let identifiers = SchemaMigrations.identifiers
        let index = try #require(identifiers.firstIndex(of: taxonomyIdentifier))
        guard index > 0 else {
            Issue.record("The taxonomy migration must never be the first migration")
            return
        }
        let queue = try MigrationHarness.database(through: identifiers[index - 1])
        try queue.write { db in
            try db.execute(sql: "CREATE TABLE taxonomy_scratch (id TEXT PRIMARY KEY NOT NULL)")
            try db.execute(sql: "INSERT INTO taxonomy_scratch (id) VALUES ('keep-me')")
        }
        try MigrationHarness.migrateToHead(queue)
        let kept = try queue.read { db in
            try String.fetchOne(db, sql: "SELECT id FROM taxonomy_scratch")
        }
        #expect(kept == "keep-me")
    }

    @Test func taxonomyTablesExistAtHead() throws {
        let database = try AppDatabase.inMemory()
        let tables = ["plant_family", "genus", "species", "cultivar"]
        let existing = try database.writer.read { db in
            try tables.filter { try db.tableExists($0) }
        }
        #expect(existing == tables)
    }

    @Test func foreignKeyColumnsAreIndexed() throws {
        let database = try AppDatabase.inMemory()
        let indexed = try database.writer.read { db -> [String: [[String]]] in
            var result: [String: [[String]]] = [:]
            for table in ["genus", "species", "cultivar"] {
                result[table] = try db.indexes(on: table).map(\.columns)
            }
            return result
        }
        #expect(indexed["genus"]?.contains(["family_id"]) == true)
        #expect(indexed["species"]?.contains(["genus_id"]) == true)
        #expect(indexed["cultivar"]?.contains(["species_id"]) == true)
    }
}
