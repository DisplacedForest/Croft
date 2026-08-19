import Domain
import Foundation
import Persistence

public struct PlantingDetail: Equatable, Sendable {
    public let planting: Planting
    public let plantName: String
    public let botanicalName: String?
    public let bedName: String
    public let locationName: String?
    public let lineage: String?

    public static func load(
        _ id: Planting.ID,
        from database: AppDatabase
    ) throws -> PlantingDetail? {
        guard let planting = try PlantingRepository(database).fetch(id: id) else {
            return nil
        }
        let names = try PlantNameIndex(database)
        let place = try BedDetail.locate(planting.bedID, GardenStructureRepository(database))
        return PlantingDetail(
            planting: planting,
            plantName: names.detailName(for: planting.identity),
            botanicalName: try botanicalName(of: planting.identity, database),
            bedName: place?.bed.name ?? "Unknown bed",
            locationName: place?.locationName,
            lineage: try lineage(of: planting.source, database)
        )
    }

    private static func botanicalName(
        of identity: PlantIdentity,
        _ database: AppDatabase
    ) throws -> String? {
        let species = SpeciesRepository(database)
        switch identity {
        case .cultivar(let id):
            guard let cultivar = try CultivarRepository(database).fetch(id: id) else {
                return nil
            }
            return try species.fetch(id: cultivar.speciesID)?.scientificName
        case .species(let id):
            return try species.fetch(id: id)?.scientificName
        }
    }

    private static func lineage(
        of source: PlantingSource?,
        _ database: AppDatabase
    ) throws -> String? {
        switch source {
        case nil:
            return nil
        case .seedLot(let id):
            let lot = try SeedLotRepository(database).fetch(id: id)
            if let origin = lot?.source {
                return "Sown from seed, \(origin)"
            }
            return "Sown from seed"
        case .starterBatch(let id):
            let batch = try StarterBatchRepository(database).fetch(id: id)
            let lot = try batch.flatMap { try SeedLotRepository(database).fetch(id: $0.seedLotID) }
            if let origin = lot?.source {
                return "Raised from starters, \(origin) seed"
            }
            return "Raised from starters"
        }
    }
}
