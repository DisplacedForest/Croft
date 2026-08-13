import Domain
import Foundation
import Persistence

public struct PlantingTimelineEvent: Equatable, Sendable {
    public let kind: PlantingActivityKind
    public let date: Date
}

public struct PlantingDetail: Equatable, Sendable {
    public let planting: Planting
    public let plantName: String
    public let botanicalName: String?
    public let bedName: String
    public let locationName: String?
    public let lineage: String?
    public let timeline: [PlantingTimelineEvent]

    public static func load(
        _ id: Planting.ID,
        from database: AppDatabase
    ) throws -> PlantingDetail? {
        guard let planting = try PlantingRepository(database).fetch(id: id) else {
            return nil
        }
        let names = try PlantNameIndex(database)
        let place = try BedDetail.locate(planting.bedID, GardenStructureRepository(database))
        var events: [PlantingTimelineEvent] = []
        if let planted = planting.plantedOn {
            events.append(PlantingTimelineEvent(kind: .planted, date: planted))
        }
        if let transplanted = planting.transplantedOn {
            events.append(PlantingTimelineEvent(kind: .transplanted, date: transplanted))
        }
        if let ended = planting.endedOn {
            events.append(
                PlantingTimelineEvent(
                    kind: planting.status == .failed ? .failed : .finished, date: ended))
        }
        return PlantingDetail(
            planting: planting,
            plantName: names.name(for: planting.identity),
            botanicalName: try botanicalName(of: planting.identity, database),
            bedName: place?.bed.name ?? "Unknown bed",
            locationName: place?.locationName,
            lineage: try lineage(of: planting.source, database),
            timeline: events.sorted { $0.date < $1.date }
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
