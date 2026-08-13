import Domain
import GRDB
import Testing

@testable import Persistence

struct TaxonomyCultivationDecodeTests {
    @Test(arguments: [
        (#"planting_seasons = '["spring","bogus"]'"#, "planting_seasons"),
        (#"seed_preps = '["soaking","bogus"]'"#, "seed_preps"),
        (#"seed_types = '["hybrid","bogus"]'"#, "seed_types"),
    ])
    func unknownCultivarListValueFailsFetch(assignments: String, column: String) throws {
        let context = try CorruptibleTaxonomy()
        try context.corruptCultivar(assignments)
        #expect(
            throws: TaxonomyCodingError.unknownRawValue(
                table: "cultivar",
                column: column,
                value: "bogus"
            )
        ) {
            try CultivarRepository(context.database).fetch(id: context.cultivar.id)
        }
    }

    @Test(arguments: [
        (
            "germination_temp_c_optimal_min = 18.0", "germination_temp_c_optimal",
            Optional("18.0"), String?.none
        ),
        (
            "germination_temp_c_optimal_max = 24.0", "germination_temp_c_optimal",
            String?.none, Optional("24.0")
        ),
        ("germination_days_min = 7", "germination_days", Optional("7"), String?.none),
        ("germination_days_max = 21", "germination_days", String?.none, Optional("21")),
        ("sowing_depth_cm_min = 1.0", "sowing_depth_cm", Optional("1.0"), String?.none),
        ("row_spacing_cm_max = 90.0", "row_spacing_cm", String?.none, Optional("90.0")),
        ("weeks_indoors_min = 6", "weeks_indoors", Optional("6"), String?.none),
    ])
    func halfSpecifiedCultivationRangeFailsFetch(
        assignments: String,
        column: String,
        lower: String?,
        upper: String?
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

    @Test func malformedFamilyCommonNamesFailsFetch() throws {
        let context = try CorruptibleTaxonomy()
        try context.corruptFamily("common_names = 'not json'")
        #expect(
            throws: TaxonomyCodingError.malformedList(
                table: "plant_family",
                column: "common_names"
            )
        ) {
            try PlantFamilyRepository(context.database).fetch(id: context.family.id)
        }
    }

    @Test func malformedSpeciesCommonNamesFailsFetch() throws {
        let context = try CorruptibleTaxonomy()
        try context.corruptSpecies("common_names = 'not json'")
        #expect(
            throws: TaxonomyCodingError.malformedList(table: "species", column: "common_names")
        ) {
            try SpeciesRepository(context.database).fetch(id: context.species.id)
        }
    }

    @Test func malformedCultivarCommonNamesFailsFetch() throws {
        let context = try CorruptibleTaxonomy()
        try context.corruptCultivar("common_names = 'not json'")
        #expect(
            throws: TaxonomyCodingError.malformedList(table: "cultivar", column: "common_names")
        ) {
            try CultivarRepository(context.database).fetch(id: context.cultivar.id)
        }
    }

    @Test(arguments: ["planting_seasons", "seed_preps", "seed_types"])
    func malformedCultivarListJSONFailsFetch(column: String) throws {
        let context = try CorruptibleTaxonomy()
        try context.corruptCultivar("\(column) = 'not json'")
        #expect(
            throws: TaxonomyCodingError.malformedList(table: "cultivar", column: column)
        ) {
            try CultivarRepository(context.database).fetch(id: context.cultivar.id)
        }
    }

    @Test func cultivationProfileRoundTripsThroughStorage() throws {
        let context = try CorruptibleTaxonomy()
        let repository = SpeciesRepository(context.database)
        var species = context.species
        species.germinationTempMin = 10.0
        species.germinationTempOptimal = 21.0...27.0
        species.germinationTempMax = 35.0
        species.germinationDays = 5...12
        species.sowingDepthCentimeters = 0.5...1.5
        species.rowSpacingCentimeters = 60.0...90.0
        species.weeksIndoorsBeforeTransplant = 5...7
        species.transplantSoilTempMin = 15.5
        try repository.update(species)
        let fetched = try #require(try repository.fetch(id: species.id))
        #expect(fetched == species)
        #expect(fetched.germinationTempMin == 10.0)
        #expect(fetched.germinationTempOptimal == 21.0...27.0)
        #expect(fetched.germinationTempMax == 35.0)
        #expect(fetched.germinationDays == 5...12)
        #expect(fetched.sowingDepthCentimeters == 0.5...1.5)
        #expect(fetched.rowSpacingCentimeters == 60.0...90.0)
        #expect(fetched.weeksIndoorsBeforeTransplant == 5...7)
        #expect(fetched.transplantSoilTempMin == 15.5)
    }

    @Test func cultivarSeedAttributesRoundTripThroughStorage() throws {
        let context = try CorruptibleTaxonomy()
        let repository = CultivarRepository(context.database)
        var cultivar = context.cultivar
        cultivar.plantingSeasons = PlantingSeason.allCases
        cultivar.seedPreps = SeedPrep.allCases
        cultivar.seedTypes = SeedType.allCases
        cultivar.heirloom = true
        try repository.update(cultivar)
        let fetched = try #require(try repository.fetch(id: cultivar.id))
        #expect(fetched == cultivar)
        #expect(fetched.plantingSeasons == PlantingSeason.allCases)
        #expect(fetched.seedPreps == SeedPrep.allCases)
        #expect(fetched.seedTypes == SeedType.allCases)
        #expect(fetched.heirloom == true)
        cultivar.heirloom = false
        try repository.update(cultivar)
        #expect(try #require(try repository.fetch(id: cultivar.id)).heirloom == false)
    }
}
