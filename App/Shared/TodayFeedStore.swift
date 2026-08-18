import Capture
import Foundation
import Persistence
import PlantCatalog
import SwiftUI
import Today

import enum Domain.DaysToMaturityBasis
import struct Domain.GardenTask
import enum Domain.HarvestYield
import enum Domain.LifecycleStage
import enum Domain.PlantIdentity
import struct Domain.Planting
import struct Domain.QuantityFormatter
import enum Domain.SowingAction

private struct GardenTaskStore {
    let repository: GardenTaskRepository

    func openTasks() throws -> [GardenTask] {
        try repository.openTasks()
    }

    func complete(id: GardenTask.ID, on date: Date) throws {
        try repository.complete(id: id, on: date)
    }
}

private struct PlantIndex {
    var names: [PlantIdentity: String] = [:]
    var daysToMaturity: [PlantIdentity: ClosedRange<Int>] = [:]
    var basis: [PlantIdentity: DaysToMaturityBasis] = [:]

    init(_ stores: AppStores) {
        var databases: [AppDatabase] = []
        if let knowledge = stores.knowledgeDatabase {
            databases.append(knowledge)
        }
        databases.append(stores.database)
        for database in databases {
            for one in (try? SpeciesRepository(database).fetchAll()) ?? [] {
                let identity = PlantIdentity.species(one.id)
                names[identity] = PlantIndex.titled(one.commonNames.first) ?? one.scientificName
                daysToMaturity[identity] = one.daysToMaturity
                basis[identity] = one.daysToMaturityBasis
            }
        }
        for database in databases {
            for one in (try? CultivarRepository(database).fetchAll()) ?? [] {
                let identity = PlantIdentity.cultivar(one.id)
                let parent = PlantIdentity.species(one.speciesID)
                names[identity] = one.name
                daysToMaturity[identity] = one.daysToMaturity ?? daysToMaturity[parent]
                basis[identity] = basis[parent]
            }
        }
    }

    private static func titled(_ name: String?) -> String? {
        guard let name, let first = name.first else {
            return name
        }
        return first.uppercased() + name.dropFirst()
    }
}

@MainActor
@Observable
final class TodayFeedStore {
    private static let recentFetchLimit = 20

    private(set) var items: [AttentionItem] = []
    private(set) var recentLines: [String] = []
    private(set) var nextWindowHint: String?

    var itemCount: Int { items.count }

    private let stores: AppStores?
    private let tasks: GardenTaskStore?
    private let photos: PhotoStore?
    private let formatter: QuantityFormatter

    init(stores: AppStores?) {
        self.stores = stores
        formatter = QuantityFormatter(system: CaptureDefaults().preferredUnitSystem)
        guard let stores else {
            tasks = nil
            photos = nil
            return
        }
        tasks = GardenTaskStore(repository: GardenTaskRepository(stores.database))
        let base =
            (try? AppDatabase.defaultURL().deletingLastPathComponent())
            .map { $0.appendingPathComponent("Photos", isDirectory: true) }
        photos = PhotoStore(
            baseURL: base
                ?? FileManager.default.temporaryDirectory
                .appendingPathComponent("CroftPhotos", isDirectory: true)
        )
    }

    func refresh(now: Date = Date()) {
        guard let stores else {
            items = []
            recentLines = []
            nextWindowHint = nil
            return
        }
        let calendar = Calendar.current
        let index = PlantIndex(stores)
        let plantings = (try? PlantingRepository(stores.database).fetchAll()) ?? []
        var names: [Planting.ID: String] = [:]
        for planting in plantings {
            names[planting.id] = index.names[planting.identity] ?? "unknown plant"
        }
        let active = plantings.filter { $0.status == .active }
        let overview = seasonOverview(stores, now: now, calendar: calendar)

        var collected = AttentionProviders.taskItems(
            openTasks: (try? tasks?.openTasks()) ?? [], now: now, calendar: calendar)
        collected += AttentionProviders.harvestChecks(
            candidates: harvestCandidates(stores, active: active, index: index, names: names),
            now: now,
            calendar: calendar
        )
        collected += AttentionProviders.plantableItems(
            groups: plantableGroups(overview), now: now, calendar: calendar)
        collected += AttentionProviders.quietItems(
            candidates: quietCandidates(stores, active: active, index: index, names: names),
            now: now,
            calendar: calendar
        )

        items = AttentionFeed.compose(collected)
        recentLines = AttentionProviders.recentLines(
            events: recentEvents(stores, names: names), now: now, calendar: calendar)
        nextWindowHint = windowHint(overview)
    }

    func complete(taskID: GardenTask.ID, now: Date = Date()) {
        try? tasks?.complete(id: taskID, on: now)
        refresh(now: now)
    }

    private func harvestCandidates(
        _ stores: AppStores,
        active: [Planting],
        index: PlantIndex,
        names: [Planting.ID: String]
    ) -> [AttentionProviders.HarvestCandidate] {
        let harvests = HarvestRepository(stores.database)
        let structures = GardenStructureRepository(stores.database)
        var locations: [String: String?] = [:]
        return active.map { planting in
            AttentionProviders.HarvestCandidate(
                plantingID: planting.id.rawValue,
                plantName: names[planting.id] ?? "unknown plant",
                locationName: locationName(
                    planting, structures: structures, cache: &locations),
                plantedOn: planting.plantedOn,
                transplantedOn: planting.transplantedOn,
                expectedMaturityOn: planting.expectedMaturityOn,
                daysToMaturity: index.daysToMaturity[planting.identity],
                basis: index.basis[planting.identity],
                firstHarvestOn: try? harvests.firstHarvestDate(forPlanting: planting.id)
            )
        }
    }

    private func quietCandidates(
        _ stores: AppStores,
        active: [Planting],
        index: PlantIndex,
        names: [Planting.ID: String]
    ) -> [AttentionProviders.QuietCandidate] {
        guard let photos else {
            return []
        }
        let observations = ObservationRepository(stores.database, photos: photos)
        let structures = GardenStructureRepository(stores.database)
        var locations: [String: String?] = [:]
        return active.map { planting in
            let latest = (try? observations.observations(on: .planting(planting.id)))?.first
            return AttentionProviders.QuietCandidate(
                plantingID: planting.id.rawValue,
                plantName: names[planting.id] ?? "unknown plant",
                locationName: locationName(
                    planting, structures: structures, cache: &locations),
                plantedOn: planting.plantedOn,
                lastObservedOn: latest?.observedAt
            )
        }
    }

    private func recentEvents(
        _ stores: AppStores,
        names: [Planting.ID: String]
    ) -> [AttentionProviders.RecentEvent] {
        var events: [AttentionProviders.RecentEvent] = []
        if let photos {
            let observations = ObservationRepository(stores.database, photos: photos)
            for observation in (try? observations.recent(limit: Self.recentFetchLimit)) ?? [] {
                guard case .planting(let plantingID) = observation.target,
                    let name = names[plantingID]
                else {
                    continue
                }
                let phrase = observation.stage.map { "\(stagePhrase($0)) the" } ?? "observed the"
                events.append(
                    AttentionProviders.RecentEvent(
                        date: observation.observedAt, text: "\(phrase) \(name)."))
            }
        }
        let harvests = HarvestRepository(stores.database)
        for harvest in (try? harvests.recent(limit: Self.recentFetchLimit)) ?? [] {
            guard let name = names[harvest.plantingID] else {
                continue
            }
            events.append(
                AttentionProviders.RecentEvent(
                    date: harvest.harvestedOn,
                    text: "harvested \(yieldText(harvest.yield)) of \(name)."))
        }
        return events
    }

    private func seasonOverview(
        _ stores: AppStores,
        now: Date,
        calendar: Calendar
    ) -> SeasonOverview? {
        let planner =
            if let knowledge = stores.knowledgeDatabase {
                SeasonPlanner(knowledge: knowledge, personal: stores.database)
            } else {
                SeasonPlanner(stores.database)
            }
        return try? planner.overview(on: now, calendar: calendar)
    }

    private func plantableGroups(
        _ overview: SeasonOverview?
    ) -> [AttentionProviders.PlantableGroup] {
        var groups: [AttentionProviders.PlantableGroup] = []
        var slots: [SowingAction: Int] = [:]
        for entry in overview?.plantableNow ?? [] {
            guard case .act(let opportunity) = entry.assessment else {
                continue
            }
            guard let slot = slots[opportunity.action] else {
                slots[opportunity.action] = groups.count
                groups.append(
                    AttentionProviders.PlantableGroup(
                        action: opportunity.action,
                        plantNames: [entry.displayName],
                        windowEnd: opportunity.window.upperBound
                    ))
                continue
            }
            let existing = groups[slot]
            groups[slot] = AttentionProviders.PlantableGroup(
                action: existing.action,
                plantNames: existing.plantNames + [entry.displayName],
                windowEnd: min(existing.windowEnd, opportunity.window.upperBound)
            )
        }
        return groups
    }

    private func windowHint(_ overview: SeasonOverview?) -> String? {
        guard let entry = overview?.upcoming.first,
            case .upcoming(let opportunity) = entry.assessment
        else {
            return nil
        }
        let opens = opportunity.window.lowerBound.formatted(
            .dateTime.month(.abbreviated).day())
        return "The next planting window opens \(opens): \(entry.displayName)."
    }

    private func locationName(
        _ planting: Planting,
        structures: GardenStructureRepository,
        cache: inout [String: String?]
    ) -> String? {
        let key = planting.bedID.rawValue
        if let cached = cache[key] {
            return cached
        }
        let resolved = resolveLocation(planting, structures: structures)
        cache[key] = resolved
        return resolved
    }

    private func resolveLocation(
        _ planting: Planting,
        structures: GardenStructureRepository
    ) -> String? {
        guard let bed = try? structures.bed(id: planting.bedID) else {
            return nil
        }
        let parent = try? structures.parent(ofBed: planting.bedID)
        let parentName: String? =
            switch parent {
            case .garden(let id): try? structures.garden(id: id)?.name
            case .growingArea(let id): try? structures.growingArea(id: id)?.name
            case nil: nil
            }
        guard let parentName else {
            return bed.name
        }
        return "\(bed.name), \(parentName)"
    }

    private func yieldText(_ yield: HarvestYield) -> String {
        switch yield {
        case .measured(let quantity):
            return formatter.string(from: quantity)
        case .custom(let amount, let label):
            let text = amount.formatted(.number.precision(.fractionLength(0...2)))
            return "\(text) \(label)"
        }
    }

    private func stagePhrase(_ stage: LifecycleStage) -> String {
        switch stage {
        case .germinated: "germinated"
        case .transplanted: "transplanted"
        case .firstFlower: "first flower on"
        case .firstFruitSet: "first fruit set on"
        case .pulled: "pulled"
        }
    }
}
