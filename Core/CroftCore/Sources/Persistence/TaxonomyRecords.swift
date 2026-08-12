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
        PlantFamily(
            id: PlantFamily.ID(rawValue: id),
            name: name,
            commonNames: try TaxonomyCoding.decodeList(String.self, from: commonNames)
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

struct SpeciesRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "species"

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
        case harvestableParts = "harvestable_parts"
    }

    init(_ species: Species) throws {
        let soilPH = TaxonomyCoding.bounds(species.soilPH)
        let spacing = TaxonomyCoding.bounds(species.spacingCentimeters)
        let maturity = TaxonomyCoding.bounds(species.daysToMaturity)
        let zones = TaxonomyCoding.bounds(species.hardinessZones)
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
    }

    func model() throws -> Species {
        let decoder = TaxonomyRowDecoder(table: Self.databaseTableName)
        return Species(
            id: Species.ID(rawValue: id),
            genusID: Genus.ID(rawValue: genusID),
            scientificName: scientificName,
            commonNames: try TaxonomyCoding.decodeList(String.self, from: commonNames),
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
    }

    func model() throws -> Cultivar {
        let decoder = TaxonomyRowDecoder(table: Self.databaseTableName)
        return Cultivar(
            id: Cultivar.ID(rawValue: id),
            speciesID: Species.ID(rawValue: speciesID),
            name: name,
            commonNames: try TaxonomyCoding.decodeList(String.self, from: commonNames),
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
            )
        )
    }
}
