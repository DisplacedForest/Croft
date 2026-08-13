import Domain
import GRDB
import Testing

@testable import Persistence

struct TaxonomyDecodeTests {
    @Test(arguments: [
        "life_cycle", "growth_habit", "sun_exposure", "water_need",
        "sowing_method", "frost_tolerance", "days_to_maturity_basis",
    ])
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
        (
            """
            germination_temp_c_optimal_min = 30.0, germination_temp_c_optimal_max = 20.0
            """,
            "germination_temp_c_optimal", "30.0", "20.0"
        ),
        ("germination_days_min = 21, germination_days_max = 7", "germination_days", "21", "7"),
        (
            "sowing_depth_cm_min = 3.0, sowing_depth_cm_max = 1.0",
            "sowing_depth_cm", "3.0", "1.0"
        ),
        (
            "row_spacing_cm_min = 90.0, row_spacing_cm_max = 45.0",
            "row_spacing_cm", "90.0", "45.0"
        ),
        ("weeks_indoors_min = 8, weeks_indoors_max = 4", "weeks_indoors", "8", "4"),
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

    @Test(arguments: [
        ("spacing_cm_min = 30.0", Optional("30.0"), String?.none),
        ("spacing_cm_max = 30.0", String?.none, Optional("30.0")),
    ])
    func halfSpecifiedSpeciesRangeFailsFetch(
        assignments: String,
        lower: String?,
        upper: String?
    ) throws {
        let context = try CorruptibleTaxonomy()
        try context.corruptSpecies(assignments)
        #expect(
            throws: TaxonomyCodingError.invalidRange(
                table: "species",
                column: "spacing_cm",
                lower: lower,
                upper: upper
            )
        ) {
            try SpeciesRepository(context.database).fetch(id: context.species.id)
        }
    }

    @Test(arguments: [
        ("days_to_maturity_min = 90, days_to_maturity_max = 30", "days_to_maturity", "90", "30"),
        ("spacing_cm_min = 60.0, spacing_cm_max = 30.0", "spacing_cm", "60.0", "30.0"),
    ])
    func invertedCultivarRangeFailsFetch(
        assignments: String,
        column: String,
        lower: String,
        upper: String
    ) throws {
        let context = try CorruptibleTaxonomy()
        try context.corruptCultivar(assignments)
        #expect(
            throws: TaxonomyCodingError.invalidRange(
                table: "cultivar",
                column: column,
                lower: lower,
                upper: upper
            )
        ) {
            try CultivarRepository(context.database).fetch(id: context.cultivar.id)
        }
    }

    @Test func corruptRowFailsEverySpeciesFetchPath() throws {
        let context = try CorruptibleTaxonomy()
        try context.corruptSpecies("water_need = 'bogus'")
        let repository = SpeciesRepository(context.database)
        let expected = TaxonomyCodingError.unknownRawValue(
            table: "species",
            column: "water_need",
            value: "bogus"
        )
        #expect(throws: expected) { try repository.fetchAll() }
        #expect(throws: expected) { try repository.species(inGenus: context.species.genusID) }
    }

    @Test func corruptRowFailsEveryCultivarFetchPath() throws {
        let context = try CorruptibleTaxonomy()
        try context.corruptCultivar("growth_habit = 'bogus'")
        let repository = CultivarRepository(context.database)
        let expected = TaxonomyCodingError.unknownRawValue(
            table: "cultivar",
            column: "growth_habit",
            value: "bogus"
        )
        #expect(throws: expected) { try repository.fetchAll() }
        #expect(throws: expected) { try repository.cultivars(ofSpecies: context.species.id) }
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
        #expect(fetched.germinationTempMin == nil)
        #expect(fetched.germinationTempOptimal == nil)
        #expect(fetched.germinationTempMax == nil)
        #expect(fetched.germinationDays == nil)
        #expect(fetched.sowingDepthCentimeters == nil)
        #expect(fetched.rowSpacingCentimeters == nil)
        #expect(fetched.sowingMethod == nil)
        #expect(fetched.weeksIndoorsBeforeTransplant == nil)
        #expect(fetched.frostTolerance == nil)
        #expect(fetched.transplantSoilTempMin == nil)
        #expect(fetched.daysToMaturityBasis == nil)
        let cultivar = try #require(
            try CultivarRepository(context.database).fetch(id: context.cultivar.id)
        )
        #expect(cultivar.growthHabit == nil)
        #expect(cultivar.daysToMaturity == nil)
        #expect(cultivar.spacingCentimeters == nil)
        #expect(cultivar.heirloom == nil)
        #expect(cultivar.plantingSeasons.isEmpty)
        #expect(cultivar.seedPreps.isEmpty)
        #expect(cultivar.seedTypes.isEmpty)
    }

    @Test func allEnumCasesRoundTripThroughStorage() throws {
        let context = try CorruptibleTaxonomy()
        let repository = SpeciesRepository(context.database)
        try expectRoundTrip(context, repository, \.lifeCycle)
        try expectRoundTrip(context, repository, \.growthHabit)
        try expectRoundTrip(context, repository, \.sunExposure)
        try expectRoundTrip(context, repository, \.waterNeed)
        try expectRoundTrip(context, repository, \.sowingMethod)
        try expectRoundTrip(context, repository, \.frostTolerance)
        try expectRoundTrip(context, repository, \.daysToMaturityBasis)
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
