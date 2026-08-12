import Domain
import Foundation
import GRDB
import Graph

struct SeedLotRecord: Codable, FetchableRecord, PersistableRecord, GraphEntity {
    static let databaseTableName = "seed_lot"
    static var entityType: EntityType { .seedLot }

    var id: String
    var cultivarID: String
    var source: String?
    var acquiredOn: Date?
    var quantity: String?
    var seedCount: Int?
    var notes: String?

    var entityID: String { id }

    var cultivarRef: EntityRef { EntityRef(id: cultivarID, type: .plant) }

    enum CodingKeys: String, CodingKey {
        case id
        case cultivarID = "cultivar_id"
        case source
        case acquiredOn = "acquired_on"
        case quantity
        case seedCount = "seed_count"
        case notes
    }

    init(_ lot: SeedLot) {
        id = lot.id.rawValue
        cultivarID = lot.cultivarID.rawValue
        source = lot.source
        acquiredOn = lot.acquiredOn
        quantity = lot.quantity
        seedCount = lot.seedCount
        notes = lot.notes
    }

    func model() -> SeedLot {
        SeedLot(
            id: SeedLot.ID(rawValue: id),
            cultivarID: Cultivar.ID(rawValue: cultivarID),
            source: source,
            acquiredOn: acquiredOn,
            quantity: quantity,
            seedCount: seedCount,
            notes: notes
        )
    }
}

struct StarterBatchRecord: Codable, FetchableRecord, PersistableRecord, GraphEntity {
    static let databaseTableName = "starter_batch"
    static var entityType: EntityType { .starterBatch }

    var id: String
    var seedLotID: String
    var sownOn: Date?
    var quantity: Int?
    var status: String

    var entityID: String { id }

    var seedLotRef: EntityRef { EntityRef(id: seedLotID, type: .seedLot) }

    enum CodingKeys: String, CodingKey {
        case id
        case seedLotID = "seed_lot_id"
        case sownOn = "sown_on"
        case quantity
        case status
    }

    init(_ batch: StarterBatch) {
        id = batch.id.rawValue
        seedLotID = batch.seedLotID.rawValue
        sownOn = batch.sownOn
        quantity = batch.quantity
        status = batch.status.rawValue
    }

    func model() throws -> StarterBatch {
        let decoder = TaxonomyRowDecoder(table: Self.databaseTableName)
        return StarterBatch(
            id: StarterBatch.ID(rawValue: id),
            seedLotID: SeedLot.ID(rawValue: seedLotID),
            sownOn: sownOn,
            quantity: quantity,
            status: try decoder.enumValue(
                StarterBatchStatus.self,
                from: status,
                column: "status"
            )
        )
    }
}
