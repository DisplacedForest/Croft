import Domain
import GRDB
import Graph

struct PestRecord: Codable, FetchableRecord, PersistableRecord, GraphEntity {
    static let databaseTableName = "pest"
    static var entityType: EntityType { .pest }

    var id: String
    var commonName: String
    var scientificName: String?
    var organismType: String
    var description: String?
    var lifeCycle: String?
    var affectedPlantParts: String
    var typicalDamage: String?
    var activeSeasons: String
    var geographicRange: String?

    var entityID: String { id }

    enum CodingKeys: String, CodingKey {
        case id
        case commonName = "common_name"
        case scientificName = "scientific_name"
        case organismType = "organism_type"
        case description
        case lifeCycle = "life_cycle"
        case affectedPlantParts = "affected_plant_parts"
        case typicalDamage = "typical_damage"
        case activeSeasons = "active_seasons"
        case geographicRange = "geographic_range"
    }

    init(_ pest: Pest) throws {
        id = pest.id.rawValue
        commonName = pest.commonName
        scientificName = pest.scientificName
        organismType = pest.organismType.rawValue
        description = pest.description
        lifeCycle = pest.lifeCycle
        affectedPlantParts = try TaxonomyCoding.encodeList(pest.affectedPlantParts)
        typicalDamage = pest.typicalDamage
        activeSeasons = try TaxonomyCoding.encodeList(pest.activeSeasons)
        geographicRange = pest.geographicRange
    }

    func model() throws -> Pest {
        guard let organism = OrganismType(rawValue: organismType) else {
            throw PestError.unknownOrganismType(organismType)
        }
        return Pest(
            id: Pest.ID(rawValue: id),
            commonName: commonName,
            scientificName: scientificName,
            organismType: organism,
            description: description,
            lifeCycle: lifeCycle,
            affectedPlantParts: try TaxonomyCoding.decodeList(
                PlantPart.self,
                from: affectedPlantParts
            ),
            typicalDamage: typicalDamage,
            activeSeasons: try TaxonomyCoding.decodeList(Season.self, from: activeSeasons),
            geographicRange: geographicRange
        )
    }
}
