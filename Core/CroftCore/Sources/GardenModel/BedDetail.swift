import Domain
import Foundation
import Persistence

public struct BedDetail: Equatable, Sendable {
    public let bed: Bed
    public let locationName: String
    public let current: [PlantingSummary]
    public let past: [PlantingSummary]

    public static func load(_ bedID: Bed.ID, from database: AppDatabase) throws -> BedDetail? {
        let structures = GardenStructureRepository(database)
        guard let place = try locate(bedID, structures) else {
            return nil
        }
        let names = try PlantNameIndex(database)
        let plantings = try PlantingRepository(database).fetchAll()
            .filter { $0.bedID == bedID }
        let current =
            plantings.filter { $0.status == .active }
            + plantings.filter { $0.status == .planned }
        let past =
            plantings
            .filter { $0.status == .finished || $0.status == .failed }
            .sorted { ($0.endedOn ?? .distantPast) > ($1.endedOn ?? .distantPast) }
        return BedDetail(
            bed: place.bed,
            locationName: place.locationName,
            current: current.map {
                PlantingSummary(planting: $0, plantName: names.name(for: $0.identity))
            },
            past: past.map {
                PlantingSummary(planting: $0, plantName: names.name(for: $0.identity))
            }
        )
    }

    static func locate(
        _ bedID: Bed.ID,
        _ structures: GardenStructureRepository
    ) throws -> (bed: Bed, locationName: String)? {
        for property in try structures.properties(includeArchived: true) {
            for garden in try structures.gardens(in: property.id, includeArchived: true) {
                let gardenBeds = try structures.beds(
                    in: .garden(garden.id), includeArchived: true)
                if let bed = gardenBeds.first(where: { $0.id == bedID }) {
                    return (bed, garden.name)
                }
                for area in try structures.growingAreas(in: garden.id, includeArchived: true) {
                    let areaBeds = try structures.beds(
                        in: .growingArea(area.id), includeArchived: true)
                    if let bed = areaBeds.first(where: { $0.id == bedID }) {
                        return (bed, "\(area.name), \(garden.name)")
                    }
                }
            }
        }
        return nil
    }
}
