import Domain
import Foundation
import Persistence

public struct PlantingSummary: Equatable, Sendable, Identifiable {
    public let planting: Planting
    public let plantName: String
    public let varietal: String?

    public init(planting: Planting, plantName: String, varietal: String? = nil) {
        self.planting = planting
        self.plantName = plantName
        self.varietal = varietal
    }

    public var id: Planting.ID { planting.id }
}

public enum PlantingActivityKind: Equatable, Sendable {
    case planted
    case transplanted
    case firstHarvest
    case finished
    case failed
}

public struct PlantingActivity: Equatable, Sendable {
    public let kind: PlantingActivityKind
    public let date: Date
    public let plantName: String
}

public struct BedSummary: Equatable, Sendable, Identifiable {
    public let bed: Bed
    public let plantings: [PlantingSummary]
    public let latestActivity: PlantingActivity?

    public var id: Bed.ID { bed.id }
}

public struct GrowingAreaGroup: Equatable, Sendable, Identifiable {
    public let area: GrowingArea
    public let beds: [BedSummary]

    public var id: GrowingArea.ID { area.id }
}

public struct GardenGroup: Equatable, Sendable, Identifiable {
    public let garden: Garden
    public let beds: [BedSummary]
    public let areas: [GrowingAreaGroup]

    public var id: Garden.ID { garden.id }
}

public struct GardenOverview: Equatable, Sendable {
    public let gardens: [GardenGroup]

    public var isEmpty: Bool { gardens.isEmpty }

    public static func load(from database: AppDatabase) throws -> GardenOverview {
        let structures = GardenStructureRepository(database)
        let names = try PlantNameIndex(database)
        let plantingsByBed = Dictionary(
            grouping: try PlantingRepository(database).fetchAll(), by: \.bedID)
        var groups: [GardenGroup] = []
        for property in try structures.properties() {
            for garden in try structures.gardens(in: property.id) {
                let beds = try structures.beds(in: .garden(garden.id))
                    .map { summary(of: $0, plantingsByBed[$0.id] ?? [], names) }
                let areas = try structures.growingAreas(in: garden.id).map { area in
                    GrowingAreaGroup(
                        area: area,
                        beds: try structures.beds(in: .growingArea(area.id))
                            .map { summary(of: $0, plantingsByBed[$0.id] ?? [], names) }
                    )
                }
                groups.append(GardenGroup(garden: garden, beds: beds, areas: areas))
            }
        }
        return GardenOverview(gardens: groups)
    }

    private static func summary(
        of bed: Bed,
        _ all: [Planting],
        _ names: PlantNameIndex
    ) -> BedSummary {
        let current = all.filter { $0.status == .active } + all.filter { $0.status == .planned }
        let activity =
            all
            .compactMap { planting in
                latestEvent(of: planting).map {
                    PlantingActivity(
                        kind: $0.kind, date: $0.date, plantName: names.name(for: planting.identity)
                    )
                }
            }
            .max { $0.date < $1.date }
        return BedSummary(
            bed: bed,
            plantings: current.map {
                PlantingSummary($0, names: names)
            },
            latestActivity: activity
        )
    }

    static func latestEvent(of planting: Planting) -> (kind: PlantingActivityKind, date: Date)? {
        var events: [(PlantingActivityKind, Date)] = []
        if let planted = planting.plantedOn {
            events.append((.planted, planted))
        }
        if let transplanted = planting.transplantedOn {
            events.append((.transplanted, transplanted))
        }
        if let ended = planting.endedOn {
            events.append((planting.status == .failed ? .failed : .finished, ended))
        }
        return events.max { $0.1 < $1.1 }.map { (kind: $0.0, date: $0.1) }
    }
}

struct PlantNameIndex {
    private let index: PlantDisplayIndex

    init(_ database: AppDatabase, locale: Locale = .current) throws {
        index = try PlantDisplayIndex(databases: [database], locale: locale)
    }

    func display(for identity: PlantIdentity) -> PlantDisplayName {
        index.display(for: identity)
    }

    func name(for identity: PlantIdentity) -> String {
        index.display(for: identity).title
    }

    func detailName(for identity: PlantIdentity) -> String {
        index.display(for: identity).detailName
    }
}

extension PlantingSummary {
    init(_ planting: Planting, names: PlantNameIndex) {
        let display = names.display(for: planting.identity)
        self.init(planting: planting, plantName: display.title, varietal: display.varietal)
    }
}
