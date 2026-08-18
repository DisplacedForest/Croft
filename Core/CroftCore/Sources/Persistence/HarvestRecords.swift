import Domain
import Foundation
import GRDB
import Graph

struct HarvestRecord: Codable, FetchableRecord, PersistableRecord, GraphEntity {
    static let databaseTableName = "harvest"
    static var entityType: EntityType { .harvest }
    static let customUnitSentinel = "custom"

    var id: String
    var plantingID: String
    var harvestedOn: Date
    var yieldAmount: Double
    var yieldUnit: String
    var yieldFamily: String?
    var customUnit: String?
    var harvestedPart: String?
    var quality: String?
    var notes: String?

    var entityID: String { id }

    var plantingRef: EntityRef { EntityRef(id: plantingID, type: .planting) }

    enum CodingKeys: String, CodingKey {
        case id
        case plantingID = "planting_id"
        case harvestedOn = "harvested_on"
        case yieldAmount = "yield_amount"
        case yieldUnit = "yield_unit"
        case yieldFamily = "yield_family"
        case customUnit = "custom_unit"
        case harvestedPart = "harvested_part"
        case quality
        case notes
    }

    static func decodeYield(
        amount: Double,
        unit: String,
        family: String?,
        customUnit: String?,
        rowID: String
    ) throws -> HarvestYield {
        if unit == customUnitSentinel {
            guard let customUnit, family == nil else {
                throw HarvestError.malformedUnit(rowID)
            }
            return .custom(amount: amount, label: customUnit)
        }
        guard
            let decoded = QuantityUnit(rawValue: unit),
            customUnit == nil,
            family == decoded.family.rawValue,
            let quantity = try? Quantity(canonicalAmount: amount, unit: decoded)
        else {
            throw HarvestError.malformedUnit(rowID)
        }
        return .measured(quantity)
    }

    init(_ harvest: Harvest) {
        id = harvest.id.rawValue
        plantingID = harvest.plantingID.rawValue
        harvestedOn = harvest.harvestedOn
        switch harvest.yield {
        case .measured(let quantity):
            yieldAmount = quantity.canonicalAmount
            yieldUnit = quantity.unit.rawValue
            yieldFamily = quantity.family.rawValue
            customUnit = nil
        case .custom(let amount, let label):
            yieldAmount = amount
            yieldUnit = Self.customUnitSentinel
            yieldFamily = nil
            customUnit = label
        }
        harvestedPart = harvest.harvestedPart?.rawValue
        quality = harvest.quality?.rawValue
        notes = harvest.notes
    }

    func model() throws -> Harvest {
        let decoder = TaxonomyRowDecoder(table: Self.databaseTableName)
        return Harvest(
            id: Harvest.ID(rawValue: id),
            plantingID: Planting.ID(rawValue: plantingID),
            harvestedOn: harvestedOn,
            yield: try Self.decodeYield(
                amount: yieldAmount,
                unit: yieldUnit,
                family: yieldFamily,
                customUnit: customUnit,
                rowID: id
            ),
            harvestedPart: try decoder.enumValue(
                HarvestablePart.self, from: harvestedPart, column: "harvested_part"),
            quality: try decoder.enumValue(HarvestQuality.self, from: quality, column: "quality"),
            notes: notes
        )
    }
}
