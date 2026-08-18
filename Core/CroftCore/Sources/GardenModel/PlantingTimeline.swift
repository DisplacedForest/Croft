import Domain
import Foundation
import Persistence

public struct PlantingTimeline: Equatable, Sendable {
    public enum EntryKind: Equatable, Sendable {
        case planted
        case stage(LifecycleStage)
        case observation(threat: Bool)
        case harvest(first: Bool)
        case ended(PlantingStatus)
    }

    public struct Entry: Equatable, Sendable, Identifiable {
        public let id: String
        public let kind: EntryKind
        public let date: Date
        public let title: String
        public let detail: String?
        public let excerpt: String?
        public let photoPath: String?
    }

    public struct Stats: Equatable, Sendable {
        public let daysToFirstHarvest: Int?
        public let totalYield: String?
        public let harvestCount: Int
    }

    public let entries: [Entry]
    public let stats: Stats

    public static func load(
        _ id: Planting.ID,
        from database: AppDatabase,
        photos: PhotoStore,
        display: UnitSystem,
        threatNames: Set<String> = []
    ) throws -> PlantingTimeline? {
        guard let planting = try PlantingRepository(database).fetch(id: id) else {
            return nil
        }
        let observations = ObservationRepository(database, photos: photos)
        let harvests = HarvestRepository(database)
        let formatter = QuantityFormatter(system: display)
        let firstHarvestDate = try harvests.firstHarvestDate(forPlanting: id)
        let plantingObservations = try observations.observations(on: .planting(id))
        let harvestRecords = try harvests.harvests(forPlanting: id)

        var entries: [Entry] = []
        let recordedStages = appendObservationEntries(
            plantingObservations,
            plantedOn: planting.plantedOn,
            threatNames: threatNames,
            into: &entries)
        try appendPlantingEntries(
            planting, recordedStages: recordedStages, database: database, into: &entries)
        let firstHarvestID = harvestRecords.min {
            ($0.harvestedOn, $0.id.rawValue) < ($1.harvestedOn, $1.id.rawValue)
        }?.id
        for harvest in harvestRecords {
            entries.append(
                harvestEntry(
                    harvest,
                    first: harvest.id == firstHarvestID,
                    plantedOn: planting.plantedOn,
                    formatter: formatter
                ))
        }
        return PlantingTimeline(
            entries: entries.sorted(by: displayOrder),
            stats: Stats(
                daysToFirstHarvest: firstHarvestDate.flatMap { first in
                    planting.plantedOn.flatMap { wholeDays(from: $0, to: first) }
                },
                totalYield: totalYield(try harvests.totals(forPlanting: id), formatter: formatter),
                harvestCount: harvestRecords.count
            )
        )
    }
}

extension PlantingTimeline {
    private static func appendObservationEntries(
        _ observations: [Observation],
        plantedOn: Date?,
        threatNames: Set<String>,
        into entries: inout [Entry]
    ) -> Set<LifecycleStage> {
        var recordedStages = Set<LifecycleStage>()
        for observation in observations {
            if let stage = observation.stage {
                recordedStages.insert(stage)
                entries.append(
                    Entry(
                        id: "stage-\(observation.id.rawValue)",
                        kind: .stage(stage),
                        date: observation.observedAt,
                        title: stage.timelineLabel,
                        detail: dayCount(for: stage, at: observation.observedAt, from: plantedOn),
                        excerpt: nil,
                        photoPath: nil
                    ))
            }
            if let entry = observationEntry(observation, threatNames: threatNames) {
                entries.append(entry)
            }
        }
        return recordedStages
    }

    private static func appendPlantingEntries(
        _ planting: Planting,
        recordedStages: Set<LifecycleStage>,
        database: AppDatabase,
        into entries: inout [Entry]
    ) throws {
        if let plantedOn = planting.plantedOn {
            entries.append(
                Entry(
                    id: "planted",
                    kind: .planted,
                    date: plantedOn,
                    title: try lineageTitle(of: planting.source, database),
                    detail: nil,
                    excerpt: planting.notes,
                    photoPath: nil
                ))
        }
        if let transplanted = planting.transplantedOn, !recordedStages.contains(.transplanted) {
            entries.append(
                Entry(
                    id: "transplanted",
                    kind: .stage(.transplanted),
                    date: transplanted,
                    title: LifecycleStage.transplanted.timelineLabel,
                    detail: dayCount(
                        for: .transplanted, at: transplanted, from: planting.plantedOn),
                    excerpt: nil,
                    photoPath: nil
                ))
        }
        if let ended = planting.endedOn, !recordedStages.contains(.pulled) {
            entries.append(
                Entry(
                    id: "ended",
                    kind: .ended(planting.status),
                    date: ended,
                    title: planting.status == .failed ? "Failed" : "Finished",
                    detail: dayCount(for: .pulled, at: ended, from: planting.plantedOn),
                    excerpt: nil,
                    photoPath: nil
                ))
        }
    }

    private static func observationEntry(
        _ observation: Observation,
        threatNames: Set<String>
    ) -> Entry? {
        let note = observation.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !note.isEmpty || !observation.photos.isEmpty else {
            return nil
        }
        let lines = note.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
        let title = lines.first.map(String.init) ?? "Observation"
        let excerpt = lines.count > 1 ? String(lines[1]).trimmingCharacters(in: .whitespaces) : nil
        return Entry(
            id: "observation-\(observation.id.rawValue)",
            kind: .observation(threat: isThreat(observation, note: note, names: threatNames)),
            date: observation.observedAt,
            title: title,
            detail: nil,
            excerpt: excerpt,
            photoPath: observation.photos.first
        )
    }

    private static func isThreat(
        _ observation: Observation,
        note: String,
        names: Set<String>
    ) -> Bool {
        if !observation.symptoms.isEmpty || !observation.tags.isEmpty {
            return true
        }
        let lowered = note.lowercased()
        return names.contains { lowered.contains($0.lowercased()) }
    }

    private static func harvestEntry(
        _ harvest: Harvest,
        first: Bool,
        plantedOn: Date?,
        formatter: QuantityFormatter
    ) -> Entry {
        var title = yieldText(harvest.yield, formatter: formatter)
        if let part = harvest.harvestedPart {
            title += ", \(part.rawValue)"
        }
        var excerptParts: [String] = []
        if let quality = harvest.quality {
            excerptParts.append("Quality \(quality.rawValue).")
        }
        if let notes = harvest.notes, !notes.isEmpty {
            excerptParts.append(notes)
        }
        let days = first ? plantedOn.flatMap { wholeDays(from: $0, to: harvest.harvestedOn) } : nil
        return Entry(
            id: "harvest-\(harvest.id.rawValue)",
            kind: .harvest(first: first),
            date: harvest.harvestedOn,
            title: title,
            detail: days.map { "\($0) days from sowing" },
            excerpt: excerptParts.isEmpty ? nil : excerptParts.joined(separator: " "),
            photoPath: nil
        )
    }

    private static func yieldText(_ yield: HarvestYield, formatter: QuantityFormatter) -> String {
        switch yield {
        case .measured(let quantity):
            return formatter.string(from: quantity)
        case .custom(let amount, let label):
            let amountText = amount.formatted(.number.precision(.fractionLength(0...2)))
            return "\(amountText) \(label)"
        }
    }

    private static func totalYield(
        _ totals: [HarvestTotal],
        formatter: QuantityFormatter
    ) -> String? {
        let best = totals.max { left, right in
            if left.count != right.count {
                return left.count < right.count
            }
            return rank(left.kind) < rank(right.kind)
        }
        guard let best else {
            return nil
        }
        switch best.kind {
        case .family(let family):
            return formatter.string(fromCanonical: best.total, family: family)
        case .custom(let label):
            let amountText = best.total.formatted(.number.precision(.fractionLength(0...2)))
            return "\(amountText) \(label)"
        }
    }

    private static func rank(_ kind: HarvestTotal.Kind) -> Int {
        switch kind {
        case .family(.mass): 3
        case .family(.volume): 2
        case .family(.count): 1
        case .custom: 0
        }
    }

    private static func lineageTitle(
        of source: PlantingSource?,
        _ database: AppDatabase
    ) throws -> String {
        switch source {
        case nil:
            return "Planted"
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

    private static func dayCount(
        for stage: LifecycleStage,
        at date: Date,
        from plantedOn: Date?
    ) -> String? {
        guard let plantedOn, let days = wholeDays(from: plantedOn, to: date) else {
            return nil
        }
        if stage == .germinated {
            return "\(days) days from sowing"
        }
        return "day \(days)"
    }

    private static func wholeDays(from start: Date, to end: Date) -> Int? {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: end)
        ).day
    }

    private static func displayOrder(_ left: Entry, _ right: Entry) -> Bool {
        if left.date != right.date {
            return left.date > right.date
        }
        if kindRank(left.kind) != kindRank(right.kind) {
            return kindRank(left.kind) > kindRank(right.kind)
        }
        return left.id < right.id
    }

    private static func kindRank(_ kind: EntryKind) -> Int {
        switch kind {
        case .ended: 5
        case .harvest: 4
        case .observation: 3
        case .stage: 2
        case .planted: 1
        }
    }
}

extension LifecycleStage {
    public var timelineLabel: String {
        switch self {
        case .germinated: "Germinated"
        case .transplanted: "Transplanted"
        case .firstFlower: "First flower"
        case .firstFruitSet: "First fruit set"
        case .pulled: "Pulled"
        }
    }
}
