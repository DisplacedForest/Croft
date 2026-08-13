import Domain
import Foundation
import GRDB
import Graph

struct PlantingRecord: Codable, FetchableRecord, PersistableRecord, GraphEntity {
    static let databaseTableName = "planting"
    static var entityType: EntityType { .planting }

    var id: String
    var cultivarID: String?
    var speciesID: String?
    var bedID: String
    var seedLotID: String?
    var starterBatchID: String?
    var plantedOn: Date?
    var transplantedOn: Date?
    var quantity: Int?
    var spacingCM: Double?
    var status: String
    var expectedMaturityOn: Date?
    var endedOn: Date?
    var notes: String?

    var entityID: String { id }

    var identityRef: EntityRef {
        EntityRef(id: cultivarID ?? speciesID ?? "", type: .plant)
    }

    var bedRef: EntityRef { EntityRef(id: bedID, type: .bed) }

    var sourceRef: EntityRef? {
        if let seedLotID {
            EntityRef(id: seedLotID, type: .seedLot)
        } else if let starterBatchID {
            EntityRef(id: starterBatchID, type: .starterBatch)
        } else {
            nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case cultivarID = "cultivar_id"
        case speciesID = "species_id"
        case bedID = "bed_id"
        case seedLotID = "seed_lot_id"
        case starterBatchID = "starter_batch_id"
        case plantedOn = "planted_on"
        case transplantedOn = "transplanted_on"
        case quantity
        case spacingCM = "spacing_cm"
        case status
        case expectedMaturityOn = "expected_maturity_on"
        case endedOn = "ended_on"
        case notes
    }

    init(_ planting: Planting) {
        id = planting.id.rawValue
        switch planting.identity {
        case .cultivar(let cultivar):
            cultivarID = cultivar.rawValue
            speciesID = nil
        case .species(let species):
            cultivarID = nil
            speciesID = species.rawValue
        }
        bedID = planting.bedID.rawValue
        switch planting.source {
        case .seedLot(let lot):
            seedLotID = lot.rawValue
            starterBatchID = nil
        case .starterBatch(let batch):
            seedLotID = nil
            starterBatchID = batch.rawValue
        case nil:
            seedLotID = nil
            starterBatchID = nil
        }
        plantedOn = planting.plantedOn
        transplantedOn = planting.transplantedOn
        quantity = planting.quantity
        spacingCM = planting.spacingCentimeters
        status = planting.status.rawValue
        expectedMaturityOn = planting.expectedMaturityOn
        endedOn = planting.endedOn
        notes = planting.notes
    }

    func model() throws -> Planting {
        let identity: PlantIdentity =
            switch (cultivarID, speciesID) {
            case (let cultivar?, nil):
                .cultivar(Cultivar.ID(rawValue: cultivar))
            case (nil, let species?):
                .species(Species.ID(rawValue: species))
            default:
                throw PlantingError.malformedIdentity(id)
            }
        let source: PlantingSource? =
            switch (seedLotID, starterBatchID) {
            case (let lot?, nil):
                .seedLot(SeedLot.ID(rawValue: lot))
            case (nil, let batch?):
                .starterBatch(StarterBatch.ID(rawValue: batch))
            case (nil, nil):
                nil
            default:
                throw PlantingError.malformedSource(id)
            }
        let decoder = TaxonomyRowDecoder(table: Self.databaseTableName)
        return Planting(
            id: Planting.ID(rawValue: id),
            identity: identity,
            bedID: Bed.ID(rawValue: bedID),
            source: source,
            plantedOn: plantedOn,
            transplantedOn: transplantedOn,
            quantity: quantity,
            spacingCentimeters: spacingCM,
            status: try decoder.enumValue(PlantingStatus.self, from: status, column: "status"),
            expectedMaturityOn: expectedMaturityOn,
            endedOn: endedOn,
            notes: notes
        )
    }
}
