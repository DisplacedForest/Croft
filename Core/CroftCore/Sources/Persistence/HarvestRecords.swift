import Domain
import Foundation
import GRDB
import Graph

struct HarvestRecord: Codable, FetchableRecord, PersistableRecord, GraphEntity {
    static let databaseTableName = "harvest"
    static var entityType: EntityType { .harvest }

    var id: String
    var plantingID: String
    var harvestedOn: Date
    var quantity: Double
    var unit: String
    var customUnit: String?
    var quality: String?
    var notes: String?

    var entityID: String { id }

    var plantingRef: EntityRef { EntityRef(id: plantingID, type: .planting) }

    enum CodingKeys: String, CodingKey {
        case id
        case plantingID = "planting_id"
        case harvestedOn = "harvested_on"
        case quantity
        case unit
        case customUnit = "custom_unit"
        case quality
        case notes
    }

    static func decodeUnit(_ raw: String) throws -> HarvestUnit {
        try TaxonomyRowDecoder(table: databaseTableName)
            .enumValue(HarvestUnit.self, from: raw, column: "unit")
    }

    init(_ harvest: Harvest) {
        id = harvest.id.rawValue
        plantingID = harvest.plantingID.rawValue
        harvestedOn = harvest.harvestedOn
        quantity = harvest.quantity
        unit = harvest.unit.rawValue
        customUnit = harvest.customUnit
        quality = harvest.quality?.rawValue
        notes = harvest.notes
    }

    func model() throws -> Harvest {
        let decoded = try Self.decodeUnit(unit)
        guard (decoded == .custom) == (customUnit != nil) else {
            throw HarvestError.malformedUnit(id)
        }
        let decoder = TaxonomyRowDecoder(table: Self.databaseTableName)
        return Harvest(
            id: Harvest.ID(rawValue: id),
            plantingID: Planting.ID(rawValue: plantingID),
            harvestedOn: harvestedOn,
            quantity: quantity,
            unit: decoded,
            customUnit: customUnit,
            quality: try decoder.enumValue(HarvestQuality.self, from: quality, column: "quality"),
            notes: notes
        )
    }
}
