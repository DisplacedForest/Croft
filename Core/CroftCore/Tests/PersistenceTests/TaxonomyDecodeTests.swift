import Domain
import GRDB
import Testing

@testable import Persistence

private struct CorruptibleTaxonomy {
    let database: AppDatabase
    let species: Species
    let cultivar: Cultivar

    init() throws {
        database = try AppDatabase.inMemory()
        let family = PlantFamily(name: "Solanaceae")
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
}

struct TaxonomyDecodeTests {
    @Test(arguments: ["life_cycle", "growth_habit", "sun_exposure", "water_need"])
    func unknownSpeciesEnumRawValueFailsFetch(column: String) throws {
        let context = try CorruptibleTaxonomy()
        try context.corruptSpecies("\(column) = 'bogus'")
        #expect(
            throws: TaxonomyCodingError.unknownRawValue(
                table: "species",
                column: column,
                value: "bogus"
            )
        ) {
            try SpeciesRepository(context.database).fetch(id: context.species.id)
        }
    }

    @Test func unknownHarvestablePartFailsFetch() throws {
        let context = try CorruptibleTaxonomy()
        try context.corruptSpecies(#"harvestable_parts = '["fruit","bogus"]'"#)
        #expect(
            throws: TaxonomyCodingError.unknownRawValue(
                table: "species",
                column: "harvestable_parts",
                value: "bogus"
            )
        ) {
            try SpeciesRepository(context.database).fetch(id: context.species.id)
        }
    }

    @Test func unknownCultivarEnumRawValueFailsFetch() throws {
        let context = try CorruptibleTaxonomy()
        try context.corruptCultivar("growth_habit = 'bogus'")
        #expect(
            throws: TaxonomyCodingError.unknownRawValue(
                table: "cultivar",
                column: "growth_habit",
                value: "bogus"
            )
        ) {
            try CultivarRepository(context.database).fetch(id: context.cultivar.id)
        }
    }

    @Test(arguments: [
        ("soil_ph_min = 7.0, soil_ph_max = 6.0", "soil_ph", "7.0", "6.0"),
        ("spacing_cm_min = 60.0, spacing_cm_max = 30.0", "spacing_cm", "60.0", "30.0"),
        ("days_to_maturity_min = 90, days_to_maturity_max = 30", "days_to_maturity", "90", "30"),
        ("hardiness_zone_min = 9, hardiness_zone_max = 3", "hardiness_zone", "9", "3"),
    ])
    func invertedSpeciesRangeFailsFetch(
        assignments: String,
        column: String,
        lower: String,
        upper: String
    ) throws {
        let context = try CorruptibleTaxonomy()
        try context.corruptSpecies(assignments)
        #expect(
            throws: TaxonomyCodingError.invalidRange(
                table: "species",
                column: column,
                lower: lower,
                upper: upper
            )
        ) {
            try SpeciesRepository(context.database).fetch(id: context.species.id)
        }
    }

    @Test func halfSpecifiedSpeciesRangeFailsFetch() throws {
        let context = try CorruptibleTaxonomy()
        try context.corruptSpecies("spacing_cm_min = 30.0")
        #expect(
            throws: TaxonomyCodingError.invalidRange(
                table: "species",
                column: "spacing_cm",
                lower: "30.0",
                upper: nil
            )
        ) {
            try SpeciesRepository(context.database).fetch(id: context.species.id)
        }
    }

    @Test func invertedCultivarRangeFailsFetch() throws {
        let context = try CorruptibleTaxonomy()
        try context.corruptCultivar("days_to_maturity_min = 90, days_to_maturity_max = 30")
        #expect(
            throws: TaxonomyCodingError.invalidRange(
                table: "cultivar",
                column: "days_to_maturity",
                lower: "90",
                upper: "30"
            )
        ) {
            try CultivarRepository(context.database).fetch(id: context.cultivar.id)
        }
    }

    @Test func corruptRowFailsFetchAll() throws {
        let context = try CorruptibleTaxonomy()
        try context.corruptSpecies("water_need = 'bogus'")
        #expect(
            throws: TaxonomyCodingError.unknownRawValue(
                table: "species",
                column: "water_need",
                value: "bogus"
            )
        ) {
            try SpeciesRepository(context.database).fetchAll()
        }
    }

    @Test func nullColumnsStillDecodeAsNil() throws {
        let context = try CorruptibleTaxonomy()
        let fetched = try #require(
            try SpeciesRepository(context.database).fetch(id: context.species.id)
        )
        #expect(fetched.lifeCycle == nil)
        #expect(fetched.growthHabit == nil)
        #expect(fetched.sunExposure == nil)
        #expect(fetched.waterNeed == nil)
        #expect(fetched.soilPH == nil)
        #expect(fetched.spacingCentimeters == nil)
        #expect(fetched.daysToMaturity == nil)
        #expect(fetched.hardinessZones == nil)
        let cultivar = try #require(
            try CultivarRepository(context.database).fetch(id: context.cultivar.id)
        )
        #expect(cultivar.growthHabit == nil)
        #expect(cultivar.daysToMaturity == nil)
        #expect(cultivar.spacingCentimeters == nil)
    }

    @Test func allEnumCasesRoundTripThroughStorage() throws {
        let context = try CorruptibleTaxonomy()
        let repository = SpeciesRepository(context.database)
        try expectRoundTrip(context, repository, \.lifeCycle)
        try expectRoundTrip(context, repository, \.growthHabit)
        try expectRoundTrip(context, repository, \.sunExposure)
        try expectRoundTrip(context, repository, \.waterNeed)
        var species = context.species
        species.harvestableParts = HarvestablePart.allCases
        try repository.update(species)
        let fetched = try #require(try repository.fetch(id: species.id))
        #expect(fetched.harvestableParts == HarvestablePart.allCases)
        let cultivars = CultivarRepository(context.database)
        for habit in GrowthHabit.allCases {
            var cultivar = context.cultivar
            cultivar.growthHabit = habit
            try cultivars.update(cultivar)
            let stored = try #require(try cultivars.fetch(id: cultivar.id))
            #expect(stored.growthHabit == habit)
        }
    }
}

private func expectRoundTrip<Value: CaseIterable & Equatable>(
    _ context: CorruptibleTaxonomy,
    _ repository: SpeciesRepository,
    _ keyPath: WritableKeyPath<Species, Value?>
) throws {
    for value in Value.allCases {
        var species = context.species
        species[keyPath: keyPath] = value
        try repository.update(species)
        let fetched = try #require(try repository.fetch(id: species.id))
        #expect(fetched[keyPath: keyPath] == value)
    }
}
