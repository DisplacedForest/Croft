import Domain
import GRDB
import Graph

struct DiseaseRecord: Codable, FetchableRecord, PersistableRecord, GraphEntity {
    static let databaseTableName = "disease"
    static var entityType: EntityType { .disease }

    var id: String
    var name: String
    var pathogen: String?
    var pathogenType: String
    var symptoms: String?
    var affectedPlantParts: String
    var transmission: String?
    var prevention: String
    var management: String

    var entityID: String { id }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case pathogen
        case pathogenType = "pathogen_type"
        case symptoms
        case affectedPlantParts = "affected_plant_parts"
        case transmission
        case prevention
        case management
    }

    init(_ disease: Disease) throws {
        id = disease.id.rawValue
        name = disease.name
        pathogen = disease.pathogen
        pathogenType = disease.pathogenType.rawValue
        symptoms = disease.symptoms
        affectedPlantParts = try TaxonomyCoding.encodeList(disease.affectedPlantParts)
        transmission = disease.transmission
        prevention = try TaxonomyCoding.encodeList(disease.prevention)
        management = try TaxonomyCoding.encodeList(disease.management)
    }

    func model() throws -> Disease {
        let decoder = TaxonomyRowDecoder(table: Self.databaseTableName)
        return Disease(
            id: Disease.ID(rawValue: id),
            name: name,
            pathogen: pathogen,
            pathogenType: try decoder.enumValue(
                PathogenType.self,
                from: pathogenType,
                column: "pathogen_type"
            ),
            symptoms: symptoms,
            affectedPlantParts: try decoder.enumList(
                PlantPart.self,
                from: affectedPlantParts,
                column: "affected_plant_parts"
            ),
            transmission: transmission,
            prevention: try decoder.stringList(from: prevention, column: "prevention"),
            management: try decoder.stringList(from: management, column: "management")
        )
    }
}

struct PathogenRecord: Codable, FetchableRecord, PersistableRecord, GraphEntity {
    static let databaseTableName = "pathogen"
    static var entityType: EntityType { .pathogen }

    var id: String
    var name: String

    var entityID: String { id }

    init(_ pathogen: Pathogen) {
        id = pathogen.id.rawValue
        name = pathogen.name
    }

    func model() -> Pathogen {
        Pathogen(id: Pathogen.ID(rawValue: id), name: name)
    }
}

struct EnvironmentalConditionRecord: Codable, FetchableRecord, PersistableRecord, GraphEntity {
    static let databaseTableName = "environmental_condition"
    static var entityType: EntityType { .environmentalCondition }

    var id: String
    var name: String

    var entityID: String { id }

    init(_ condition: EnvironmentalCondition) {
        id = condition.id.rawValue
        name = condition.name
    }

    func model() -> EnvironmentalCondition {
        EnvironmentalCondition(id: EnvironmentalCondition.ID(rawValue: id), name: name)
    }
}
