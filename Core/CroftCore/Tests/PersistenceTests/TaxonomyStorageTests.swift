import Domain
import GRDB
import Testing

@testable import Persistence

private let taxonomyIdentifier = "v003-taxonomy"
private let cultivationProfilePredecessor = "v008-seed-lots"

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

private func cultivarRow(_ database: AppDatabase, id: Cultivar.ID) throws -> Row {
    let row = try database.writer.read { db in
        try Row.fetchOne(db, sql: "SELECT * FROM cultivar WHERE id = ?", arguments: [id.rawValue])
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
            "germination_temp_c_min", "germination_temp_c_optimal_min",
            "germination_temp_c_optimal_max", "germination_temp_c_max",
            "germination_days_min", "germination_days_max",
            "sowing_depth_cm_min", "sowing_depth_cm_max",
            "row_spacing_cm_min", "row_spacing_cm_max", "sowing_method",
            "weeks_indoors_min", "weeks_indoors_max", "frost_tolerance",
            "transplant_soil_temp_c_min", "days_to_maturity_basis",
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

    @Test func cultivationRangesAreStoredAsBoundColumns() throws {
        let seed = try SeededTaxonomy()
        let database = seed.database
        var species = seed.species
        species.germinationTempMin = 10.0
        species.germinationTempOptimal = 21.0...27.0
        species.germinationTempMax = 35.0
        species.germinationDays = 5...12
        species.sowingDepthCentimeters = 0.5...1.5
        species.rowSpacingCentimeters = 60.0...90.0
        species.weeksIndoorsBeforeTransplant = 5...7
        species.transplantSoilTempMin = 15.5
        try SpeciesRepository(database).insert(species)
        let row = try speciesRow(database, id: species.id)
        #expect(row["germination_temp_c_min"] == 10.0)
        #expect(row["germination_temp_c_optimal_min"] == 21.0)
        #expect(row["germination_temp_c_optimal_max"] == 27.0)
        #expect(row["germination_temp_c_max"] == 35.0)
        #expect(row["germination_days_min"] == 5)
        #expect(row["germination_days_max"] == 12)
        #expect(row["sowing_depth_cm_min"] == 0.5)
        #expect(row["row_spacing_cm_max"] == 90.0)
        #expect(row["weeks_indoors_min"] == 5)
        #expect(row["transplant_soil_temp_c_min"] == 15.5)
        let fetched = try #require(try SpeciesRepository(database).fetch(id: species.id))
        #expect(fetched == species)
    }

    @Test func cultivarSeedListsAreStoredAsJSONText() throws {
        let seed = try SeededTaxonomy()
        let database = seed.database
        try SpeciesRepository(database).insert(seed.species)
        var cultivar = Cultivar(speciesID: seed.species.id, name: "San Marzano")
        cultivar.plantingSeasons = [.spring, .warmSeason]
        cultivar.seedPreps = [.soaking, .coldStratification]
        cultivar.seedTypes = [.heirloom, .openPollinated]
        cultivar.heirloom = true
        try CultivarRepository(database).insert(cultivar)
        let row = try cultivarRow(database, id: cultivar.id)
        #expect(row["planting_seasons"] == "[\"spring\",\"warmSeason\"]")
        #expect(row["seed_preps"] == "[\"soaking\",\"coldStratification\"]")
        #expect(row["seed_types"] == "[\"heirloom\",\"openPollinated\"]")
        #expect(row["heirloom"] == 1)
        let fetched = try #require(try CultivarRepository(database).fetch(id: cultivar.id))
        #expect(fetched == cultivar)
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

    @Test func invertedCultivationRangeIsRejected() throws {
        let seed = try SeededTaxonomy()
        let database = seed.database
        let genus = seed.genus
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO species (
                            id, genus_id, scientific_name,
                            germination_days_min, germination_days_max
                        )
                        VALUES ('inverted-germination', ?, 'Solanum tardum', 21, 7)
                        """,
                    arguments: [genus.id.rawValue]
                )
            }
        }
    }

    @Test func halfPopulatedCultivationRangeIsRejected() throws {
        let seed = try SeededTaxonomy()
        let database = seed.database
        let genus = seed.genus
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO species (id, genus_id, scientific_name, weeks_indoors_min)
                        VALUES ('half-weeks', ?, 'Solanum praecox', 6)
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

struct CultivationProfileMigrationTests {
    private func seededQueue() throws -> DatabaseQueue {
        let queue = try MigrationHarness.database(through: cultivationProfilePredecessor)
        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO plant_family (id, name, common_names)
                    VALUES ('f1', 'Solanaceae', '["nightshades"]')
                    """
            )
            try db.execute(
                sql: "INSERT INTO genus (id, family_id, name) VALUES ('g1', 'f1', 'Solanum')")
            try db.execute(
                sql: """
                    INSERT INTO species (
                        id, genus_id, scientific_name, common_names,
                        life_cycle, soil_ph_min, soil_ph_max,
                        days_to_maturity_min, days_to_maturity_max, harvestable_parts
                    )
                    VALUES ('s1', 'g1', 'Solanum lycopersicum', '["tomato"]',
                            'annual', 6.0, 6.8, 60, 85, '["fruit"]')
                    """
            )
            try db.execute(
                sql: """
                    INSERT INTO cultivar (
                        id, species_id, name, common_names,
                        days_to_maturity_min, days_to_maturity_max, growth_habit
                    )
                    VALUES ('c1', 's1', 'San Marzano', '["roma"]', 75, 90, 'vine')
                    """
            )
        }
        return queue
    }

    @Test func speciesRowsSurviveTheCultivationProfileRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let row = try queue.read { db in
            try #require(try Row.fetchOne(db, sql: "SELECT * FROM species WHERE id = 's1'"))
        }
        #expect(row["scientific_name"] == "Solanum lycopersicum")
        #expect(row["common_names"] == "[\"tomato\"]")
        #expect(row["life_cycle"] == "annual")
        #expect(row["soil_ph_min"] == 6.0)
        #expect(row["days_to_maturity_max"] == 85)
        #expect(row["harvestable_parts"] == "[\"fruit\"]")
        #expect(row["germination_temp_c_min"] == DatabaseValue.null)
        #expect(row["germination_days_min"] == DatabaseValue.null)
        #expect(row["sowing_method"] == DatabaseValue.null)
        #expect(row["frost_tolerance"] == DatabaseValue.null)
        #expect(row["days_to_maturity_basis"] == DatabaseValue.null)
    }

    @Test func cultivarRowsSurviveTheCultivationProfileRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let row = try queue.read { db in
            try #require(try Row.fetchOne(db, sql: "SELECT * FROM cultivar WHERE id = 'c1'"))
        }
        #expect(row["name"] == "San Marzano")
        #expect(row["common_names"] == "[\"roma\"]")
        #expect(row["days_to_maturity_min"] == 75)
        #expect(row["growth_habit"] == "vine")
        #expect(row["planting_seasons"] == "[]")
        #expect(row["seed_preps"] == "[]")
        #expect(row["seed_types"] == "[]")
        #expect(row["heirloom"] == DatabaseValue.null)
    }

    @Test func foreignKeyIndexesSurviveTheRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let indexed = try queue.read { db -> [String: [[String]]] in
            var result: [String: [[String]]] = [:]
            for table in ["species", "cultivar"] {
                result[table] = try db.indexes(on: table).map(\.columns)
            }
            return result
        }
        #expect(indexed["species"]?.contains(["genus_id"]) == true)
        #expect(indexed["cultivar"]?.contains(["species_id"]) == true)
    }
}
