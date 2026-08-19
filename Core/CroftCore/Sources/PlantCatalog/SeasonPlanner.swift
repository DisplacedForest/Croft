import Domain
import Foundation
import Persistence

public struct SeasonEntry: Equatable, Identifiable, Sendable {
    public let id: String
    public let identity: PlantIdentity
    public let displayName: String
    public let assessment: PlantingWindowAssessment
    public let profile: PlantingWindowProfile
}

public struct SeasonPlanting: Equatable, Identifiable, Sendable {
    public let planting: Planting
    public let plantName: String
    public let varietal: String?
    public let locationName: String?

    public var id: String { planting.id.rawValue }
}

public struct SeasonOverview: Equatable, Sendable {
    public let anchors: FrostAnchors?
    public let plantableNow: [SeasonEntry]
    public let upcoming: [SeasonEntry]
    public let unassessed: [SeasonEntry]
    public let planned: [SeasonPlanting]
    public let inGround: [SeasonPlanting]
    public let finished: [SeasonPlanting]

    public var hasFrostDates: Bool {
        anchors?.lastFrost != nil
    }
}

public struct SeasonPlanner: Sendable {
    public static let upcomingHorizonDays = 60

    private let species: SpeciesRepository
    private let cultivars: CultivarRepository
    private let nameDatabases: [AppDatabase]
    private let plantings: PlantingRepository
    private let structures: GardenStructureRepository

    public init(knowledge: AppDatabase, personal: AppDatabase) {
        species = SpeciesRepository(knowledge)
        cultivars = CultivarRepository(knowledge)
        nameDatabases = [knowledge, personal]
        plantings = PlantingRepository(personal)
        structures = GardenStructureRepository(personal)
    }

    public init(_ database: AppDatabase) {
        self.init(knowledge: database, personal: database)
    }

    public func overview(
        on reference: Date = Date(),
        calendar: Calendar = PlantingWindows.utcCalendar
    ) throws -> SeasonOverview {
        let property = try structures.properties(includeArchived: true).first
        let anchors = property.map(FrostAnchors.init(property:))
        let allSpecies = try species.fetchAll()
        let allCultivars = try cultivars.fetchAll()

        var sowing = SowingEntries()
        if let anchors, anchors.lastFrost != nil {
            sowing = sowingEntries(
                species: allSpecies, anchors: anchors, on: reference, calendar: calendar)
        }

        let names = try PlantDisplayIndex(databases: nameDatabases)
        let groups = try plantingGroups(
            names: names,
            year: calendar.component(.year, from: reference),
            calendar: calendar
        )

        return SeasonOverview(
            anchors: anchors,
            plantableNow: sowing.plantable,
            upcoming: sowing.upcoming,
            unassessed: sowing.unassessed,
            planned: groups.planned,
            inGround: groups.inGround,
            finished: groups.finished
        )
    }

    private struct SowingEntries {
        var plantable: [SeasonEntry] = []
        var upcoming: [SeasonEntry] = []
        var unassessed: [SeasonEntry] = []
    }

    private struct PlantingGroups {
        var planned: [SeasonPlanting] = []
        var inGround: [SeasonPlanting] = []
        var finished: [SeasonPlanting] = []
    }

    private func sowingEntries(
        species allSpecies: [Species],
        anchors: FrostAnchors,
        on reference: Date,
        calendar: Calendar
    ) -> SowingEntries {
        let horizon = calendar.date(
            byAdding: .day, value: SeasonPlanner.upcomingHorizonDays, to: reference)!
        var entries = SowingEntries()
        for one in allSpecies {
            let profile = PlantingWindowProfile(species: one)
            let entry = SeasonEntry(
                id: one.id.rawValue,
                identity: .species(one.id),
                displayName: titled(one.commonNames.first) ?? one.scientificName,
                assessment: PlantingWindows.assess(
                    profile, anchors: anchors, on: reference, calendar: calendar),
                profile: profile
            )
            switch entry.assessment {
            case .act:
                entries.plantable.append(entry)
            case .upcoming(let opportunity)
            where opportunity.window.lowerBound <= horizon:
                entries.upcoming.append(entry)
            case .cannotAssess:
                entries.unassessed.append(entry)
            default:
                break
            }
        }
        entries.plantable.sort {
            windowEnd($0) == windowEnd($1)
                ? $0.displayName < $1.displayName
                : windowEnd($0) < windowEnd($1)
        }
        entries.upcoming.sort {
            windowStart($0) == windowStart($1)
                ? $0.displayName < $1.displayName
                : windowStart($0) < windowStart($1)
        }
        entries.unassessed.sort { $0.displayName < $1.displayName }
        return entries
    }

    private func plantingGroups(
        names: PlantDisplayIndex,
        year: Int,
        calendar: Calendar
    ) throws -> PlantingGroups {
        var groups = PlantingGroups()
        for planting in try plantings.fetchAll() {
            let display = names.display(for: planting.identity)
            let summary = SeasonPlanting(
                planting: planting,
                plantName: display.title,
                varietal: display.varietal,
                locationName: try locationName(ofBed: planting.bedID)
            )
            switch planting.status {
            case .planned:
                groups.planned.append(summary)
            case .active:
                groups.inGround.append(summary)
            case .finished, .failed:
                let endedYear = planting.endedOn.map { calendar.component(.year, from: $0) }
                if endedYear == nil || endedYear == year {
                    groups.finished.append(summary)
                }
            }
        }
        groups.planned.sort { $0.plantName < $1.plantName }
        groups.inGround.sort {
            ($0.planting.plantedOn ?? .distantPast) > ($1.planting.plantedOn ?? .distantPast)
        }
        groups.finished.sort {
            ($0.planting.endedOn ?? .distantPast) > ($1.planting.endedOn ?? .distantPast)
        }
        return groups
    }

    private func windowEnd(_ entry: SeasonEntry) -> Date {
        if case .act(let opportunity) = entry.assessment {
            return opportunity.window.upperBound
        }
        return .distantFuture
    }

    private func windowStart(_ entry: SeasonEntry) -> Date {
        if case .upcoming(let opportunity) = entry.assessment {
            return opportunity.window.lowerBound
        }
        return .distantFuture
    }

    private func locationName(ofBed bedID: Bed.ID) throws -> String? {
        guard let bed = try structures.bed(id: bedID) else {
            return nil
        }
        let parentName: String? =
            switch try structures.parent(ofBed: bedID) {
            case .garden(let id): try structures.garden(id: id)?.name
            case .growingArea(let id): try structures.growingArea(id: id)?.name
            case nil: nil
            }
        guard let parentName else {
            return bed.name
        }
        return "\(bed.name), \(parentName)"
    }

    private func titled(_ name: String?) -> String? {
        guard let name, let first = name.first else {
            return name
        }
        return first.uppercased() + name.dropFirst()
    }
}
