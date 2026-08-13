import Domain
import GRDB
import Graph

struct PlantFamilyRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "plant_family"

    var id: String
    var name: String
    var commonNames: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case commonNames = "common_names"
    }

    init(_ family: PlantFamily) throws {
        id = family.id.rawValue
        name = family.name
        commonNames = try TaxonomyCoding.encodeList(family.commonNames)
    }

    func model() throws -> PlantFamily {
        let decoder = TaxonomyRowDecoder(table: Self.databaseTableName)
        return PlantFamily(
            id: PlantFamily.ID(rawValue: id),
            name: name,
            commonNames: try decoder.stringList(from: commonNames, column: "common_names")
        )
    }
}

struct GenusRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "genus"

    var id: String
    var familyID: String
    var name: String

    enum CodingKeys: String, CodingKey {
        case id
        case familyID = "family_id"
        case name
    }

    init(_ genus: Genus) {
        id = genus.id.rawValue
        familyID = genus.familyID.rawValue
        name = genus.name
    }

    func model() -> Genus {
        Genus(
            id: Genus.ID(rawValue: id),
            familyID: PlantFamily.ID(rawValue: familyID),
            name: name
        )
    }
}

struct SpeciesRecord: Codable, FetchableRecord, PersistableRecord, GraphEntity {
    static let databaseTableName = "species"
    static var entityType: EntityType { .plant }

    var entityID: String { id }

    var id: String
    var genusID: String
    var scientificName: String
    var commonNames: String
    var lifeCycle: String?
    var growthHabit: String?
    var sunExposure: String?
    var waterNeed: String?
    var soilPHMin: Double?
    var soilPHMax: Double?
    var spacingMin: Double?
    var spacingMax: Double?
    var daysToMaturityMin: Int?
    var daysToMaturityMax: Int?
    var hardinessZoneMin: Int?
    var hardinessZoneMax: Int?
    var germinationTempMin: Double?
    var germinationTempOptimalMin: Double?
    var germinationTempOptimalMax: Double?
    var germinationTempMax: Double?
    var germinationDaysMin: Int?
    var germinationDaysMax: Int?
    var sowingDepthMin: Double?
    var sowingDepthMax: Double?
    var rowSpacingMin: Double?
    var rowSpacingMax: Double?
    var sowingMethod: String?
    var weeksIndoorsMin: Int?
    var weeksIndoorsMax: Int?
    var frostTolerance: String?
    var transplantSoilTempMin: Double?
    var daysToMaturityBasis: String?
    var harvestableParts: String

    enum CodingKeys: String, CodingKey {
        case id
        case genusID = "genus_id"
        case scientificName = "scientific_name"
        case commonNames = "common_names"
        case lifeCycle = "life_cycle"
        case growthHabit = "growth_habit"
        case sunExposure = "sun_exposure"
        case waterNeed = "water_need"
        case soilPHMin = "soil_ph_min"
        case soilPHMax = "soil_ph_max"
        case spacingMin = "spacing_cm_min"
        case spacingMax = "spacing_cm_max"
        case daysToMaturityMin = "days_to_maturity_min"
        case daysToMaturityMax = "days_to_maturity_max"
        case hardinessZoneMin = "hardiness_zone_min"
        case hardinessZoneMax = "hardiness_zone_max"
        case germinationTempMin = "germination_temp_c_min"
        case germinationTempOptimalMin = "germination_temp_c_optimal_min"
        case germinationTempOptimalMax = "germination_temp_c_optimal_max"
        case germinationTempMax = "germination_temp_c_max"
        case germinationDaysMin = "germination_days_min"
        case germinationDaysMax = "germination_days_max"
        case sowingDepthMin = "sowing_depth_cm_min"
        case sowingDepthMax = "sowing_depth_cm_max"
        case rowSpacingMin = "row_spacing_cm_min"
        case rowSpacingMax = "row_spacing_cm_max"
        case sowingMethod = "sowing_method"
        case weeksIndoorsMin = "weeks_indoors_min"
        case weeksIndoorsMax = "weeks_indoors_max"
        case frostTolerance = "frost_tolerance"
        case transplantSoilTempMin = "transplant_soil_temp_c_min"
        case daysToMaturityBasis = "days_to_maturity_basis"
        case harvestableParts = "harvestable_parts"
    }

    init(_ species: Species) throws {
        let soilPH = TaxonomyCoding.bounds(species.soilPH)
        let spacing = TaxonomyCoding.bounds(species.spacingCentimeters)
        let maturity = TaxonomyCoding.bounds(species.daysToMaturity)
        let zones = TaxonomyCoding.bounds(species.hardinessZones)
        let germinationTemp = TaxonomyCoding.bounds(species.germinationTempOptimal)
        let germination = TaxonomyCoding.bounds(species.germinationDays)
        let sowingDepth = TaxonomyCoding.bounds(species.sowingDepthCentimeters)
        let rowSpacing = TaxonomyCoding.bounds(species.rowSpacingCentimeters)
        let weeksIndoors = TaxonomyCoding.bounds(species.weeksIndoorsBeforeTransplant)
        id = species.id.rawValue
        genusID = species.genusID.rawValue
        scientificName = species.scientificName
        commonNames = try TaxonomyCoding.encodeList(species.commonNames)
        lifeCycle = species.lifeCycle?.rawValue
        growthHabit = species.growthHabit?.rawValue
        sunExposure = species.sunExposure?.rawValue
        waterNeed = species.waterNeed?.rawValue
        soilPHMin = soilPH.lower
        soilPHMax = soilPH.upper
        spacingMin = spacing.lower
        spacingMax = spacing.upper
        daysToMaturityMin = maturity.lower
        daysToMaturityMax = maturity.upper
        hardinessZoneMin = zones.lower
        hardinessZoneMax = zones.upper
        harvestableParts = try TaxonomyCoding.encodeList(species.harvestableParts)
        germinationTempMin = species.germinationTempMin
        germinationTempOptimalMin = germinationTemp.lower
        germinationTempOptimalMax = germinationTemp.upper
        germinationTempMax = species.germinationTempMax
        germinationDaysMin = germination.lower
        germinationDaysMax = germination.upper
        sowingDepthMin = sowingDepth.lower
        sowingDepthMax = sowingDepth.upper
        rowSpacingMin = rowSpacing.lower
        rowSpacingMax = rowSpacing.upper
        sowingMethod = species.sowingMethod?.rawValue
        weeksIndoorsMin = weeksIndoors.lower
        weeksIndoorsMax = weeksIndoors.upper
        frostTolerance = species.frostTolerance?.rawValue
        transplantSoilTempMin = species.transplantSoilTempMin
        daysToMaturityBasis = species.daysToMaturityBasis?.rawValue
    }

    func model() throws -> Species {
        let decoder = TaxonomyRowDecoder(table: Self.databaseTableName)
        var species = Species(
            id: Species.ID(rawValue: id),
            genusID: Genus.ID(rawValue: genusID),
            scientificName: scientificName,
            commonNames: try decoder.stringList(from: commonNames, column: "common_names"),
            lifeCycle: try decoder.enumValue(LifeCycle.self, from: lifeCycle, column: "life_cycle"),
            growthHabit: try decoder.enumValue(
                GrowthHabit.self,
                from: growthHabit,
                column: "growth_habit"
            ),
            sunExposure: try decoder.enumValue(
                SunExposure.self,
                from: sunExposure,
                column: "sun_exposure"
            ),
            waterNeed: try decoder.enumValue(WaterNeed.self, from: waterNeed, column: "water_need"),
            soilPH: try decoder.range(lower: soilPHMin, upper: soilPHMax, column: "soil_ph"),
            spacingCentimeters: try decoder.range(
                lower: spacingMin,
                upper: spacingMax,
                column: "spacing_cm"
            ),
            daysToMaturity: try decoder.range(
                lower: daysToMaturityMin,
                upper: daysToMaturityMax,
                column: "days_to_maturity"
            ),
            hardinessZones: try decoder.range(
                lower: hardinessZoneMin,
                upper: hardinessZoneMax,
                column: "hardiness_zone"
            ),
            harvestableParts: try decoder.enumList(
                HarvestablePart.self,
                from: harvestableParts,
                column: "harvestable_parts"
            )
        )
        try decodeCultivationProfile(into: &species, decoder: decoder)
        return species
    }

    private func decodeCultivationProfile(
        into species: inout Species,
        decoder: TaxonomyRowDecoder
    ) throws {
        species.germinationTempMin = germinationTempMin
        species.germinationTempOptimal = try decoder.range(
            lower: germinationTempOptimalMin,
            upper: germinationTempOptimalMax,
            column: "germination_temp_c_optimal"
        )
        species.germinationTempMax = germinationTempMax
        species.germinationDays = try decoder.range(
            lower: germinationDaysMin,
            upper: germinationDaysMax,
            column: "germination_days"
        )
        species.sowingDepthCentimeters = try decoder.range(
            lower: sowingDepthMin,
            upper: sowingDepthMax,
            column: "sowing_depth_cm"
        )
        species.rowSpacingCentimeters = try decoder.range(
            lower: rowSpacingMin,
            upper: rowSpacingMax,
            column: "row_spacing_cm"
        )
        species.sowingMethod = try decoder.enumValue(
            SowingMethod.self,
            from: sowingMethod,
            column: "sowing_method"
        )
        species.weeksIndoorsBeforeTransplant = try decoder.range(
            lower: weeksIndoorsMin,
            upper: weeksIndoorsMax,
            column: "weeks_indoors"
        )
        species.frostTolerance = try decoder.enumValue(
            FrostTolerance.self,
            from: frostTolerance,
            column: "frost_tolerance"
        )
        species.transplantSoilTempMin = transplantSoilTempMin
        species.daysToMaturityBasis = try decoder.enumValue(
            DaysToMaturityBasis.self,
            from: daysToMaturityBasis,
            column: "days_to_maturity_basis"
        )
    }
}

struct CultivarRecord: Codable, FetchableRecord, PersistableRecord, GraphEntity {
    static let databaseTableName = "cultivar"
    static var entityType: EntityType { .plant }

    var id: String
    var speciesID: String
    var name: String
    var commonNames: String
    var daysToMaturityMin: Int?
    var daysToMaturityMax: Int?
    var spacingMin: Double?
    var spacingMax: Double?
    var growthHabit: String?
    var plantingSeasons: String
    var seedPreps: String
    var heirloom: Bool?
    var seedTypes: String

    var entityID: String { id }

    enum CodingKeys: String, CodingKey {
        case id
        case speciesID = "species_id"
        case name
        case commonNames = "common_names"
        case daysToMaturityMin = "days_to_maturity_min"
        case daysToMaturityMax = "days_to_maturity_max"
        case spacingMin = "spacing_cm_min"
        case spacingMax = "spacing_cm_max"
        case growthHabit = "growth_habit"
        case plantingSeasons = "planting_seasons"
        case seedPreps = "seed_preps"
        case heirloom
        case seedTypes = "seed_types"
    }

    init(_ cultivar: Cultivar) throws {
        let maturity = TaxonomyCoding.bounds(cultivar.daysToMaturity)
        let spacing = TaxonomyCoding.bounds(cultivar.spacingCentimeters)
        id = cultivar.id.rawValue
        speciesID = cultivar.speciesID.rawValue
        name = cultivar.name
        commonNames = try TaxonomyCoding.encodeList(cultivar.commonNames)
        daysToMaturityMin = maturity.lower
        daysToMaturityMax = maturity.upper
        spacingMin = spacing.lower
        spacingMax = spacing.upper
        growthHabit = cultivar.growthHabit?.rawValue
        plantingSeasons = try TaxonomyCoding.encodeList(cultivar.plantingSeasons)
        seedPreps = try TaxonomyCoding.encodeList(cultivar.seedPreps)
        heirloom = cultivar.heirloom
        seedTypes = try TaxonomyCoding.encodeList(cultivar.seedTypes)
    }

    func model() throws -> Cultivar {
        let decoder = TaxonomyRowDecoder(table: Self.databaseTableName)
        return Cultivar(
            id: Cultivar.ID(rawValue: id),
            speciesID: Species.ID(rawValue: speciesID),
            name: name,
            commonNames: try decoder.stringList(from: commonNames, column: "common_names"),
            daysToMaturity: try decoder.range(
                lower: daysToMaturityMin,
                upper: daysToMaturityMax,
                column: "days_to_maturity"
            ),
            spacingCentimeters: try decoder.range(
                lower: spacingMin,
                upper: spacingMax,
                column: "spacing_cm"
            ),
            growthHabit: try decoder.enumValue(
                GrowthHabit.self,
                from: growthHabit,
                column: "growth_habit"
            ),
            plantingSeasons: try decoder.enumList(
                PlantingSeason.self,
                from: plantingSeasons,
                column: "planting_seasons"
            ),
            seedPreps: try decoder.enumList(SeedPrep.self, from: seedPreps, column: "seed_preps"),
            heirloom: heirloom,
            seedTypes: try decoder.enumList(SeedType.self, from: seedTypes, column: "seed_types")
        )
    }
}
