import Domain
import Foundation
import GRDB
import Graph

public enum ChangeReplayError: Error, Equatable {
    case orphanedStructure(String)
    case malformedWeatherKey(String)
}

public struct ChangeReplayer {
    private let source: AppDatabase
    private let target: AppDatabase
    private let sourceObservations: ObservationRepository
    private let targetObservations: ObservationRepository

    public init(source: AppDatabase, target: AppDatabase) {
        self.source = source
        self.target = target
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("croft-replay-\(UUID().uuidString)", isDirectory: true)
        sourceObservations = ObservationRepository(
            source, photos: PhotoStore(baseURL: scratch.appendingPathComponent("source")))
        targetObservations = ObservationRepository(
            target, photos: PhotoStore(baseURL: scratch.appendingPathComponent("target")))
    }

    public func replayAll() throws {
        try replay(ChangeLogRepository(source).all())
    }

    public func replay(_ records: [ChangeRecord]) throws {
        let reduced = Self.reduce(records)
        let upserts = reduced.filter { $0.operation != .delete }.sorted(by: Self.applyOrder)
        let deletes = reduced.filter { $0.operation == .delete }.sorted(by: Self.deleteOrder)
        for change in upserts {
            try apply(change)
        }
        for change in deletes {
            try remove(change)
        }
    }

    static func reduce(_ records: [ChangeRecord]) -> [ChangeRecord] {
        var latest: [String: ChangeRecord] = [:]
        for record in records {
            let key = "\(record.kind.rawValue)#\(record.entityID)"
            if let existing = latest[key], Self.supersedes(existing, record) {
                continue
            }
            latest[key] = record
        }
        return Array(latest.values)
    }

    static func supersedes(_ existing: ChangeRecord, _ candidate: ChangeRecord) -> Bool {
        (existing.changedAt, existing.sequence) >= (candidate.changedAt, candidate.sequence)
    }

    static func applyOrder(_ left: ChangeRecord, _ right: ChangeRecord) -> Bool {
        (rank(left.kind), left.changedAt, left.sequence)
            < (rank(right.kind), right.changedAt, right.sequence)
    }

    static func deleteOrder(_ left: ChangeRecord, _ right: ChangeRecord) -> Bool {
        (rank(left.kind), left.changedAt, left.sequence)
            > (rank(right.kind), right.changedAt, right.sequence)
    }

    static let ranks: [ChangeKind: Int] = [
        .plantFamily: 1, .genus: 2, .species: 3, .cultivar: 4,
        .pest: 5, .pathogen: 6, .disease: 7, .environmentalCondition: 8,
        .property: 9, .garden: 10, .growingArea: 11, .bed: 12,
        .seedLot: 13, .starterBatch: 14, .planting: 15,
        .observation: 16, .observationPhoto: 17,
        .harvest: 18, .task: 19, .dailyWeather: 20,
    ]

    static func rank(_ kind: ChangeKind) -> Int {
        ranks[kind] ?? 0
    }

    private func apply(_ change: ChangeRecord) throws {
        switch change.kind {
        case .property, .garden, .growingArea, .bed:
            try applyStructure(change)
        default:
            if try applyTaxon(change) {
                return
            }
            if try applyGrowth(change) {
                return
            }
            try applyOutcome(change)
        }
    }

    private func applyStructure(_ change: ChangeRecord) throws {
        let from = GardenStructureRepository(source)
        let into = GardenStructureRepository(target)
        let id = change.entityID
        switch change.kind {
        case .property:
            if let model = try from.property(id: Property.ID(rawValue: id)) {
                try into.apply(model)
            }
        case .garden:
            if let model = try from.garden(id: Garden.ID(rawValue: id)) {
                try into.apply(model, in: Property.ID(rawValue: try locatedInParent(of: id)))
            }
        case .growingArea:
            if let model = try from.growingArea(id: GrowingArea.ID(rawValue: id)) {
                try into.apply(model, in: Garden.ID(rawValue: try locatedInParent(of: id)))
            }
        case .bed:
            let bedID = Bed.ID(rawValue: id)
            if let model = try from.bed(id: bedID), let parent = try from.parent(ofBed: bedID) {
                try into.apply(model, in: parent)
            }
        default:
            break
        }
    }

    private func applyTaxon(_ change: ChangeRecord) throws -> Bool {
        let id = change.entityID
        switch change.kind {
        case .plantFamily:
            try applyModel(id, PlantFamilyRepository(source), PlantFamilyRepository(target))
        case .genus:
            try applyModel(id, GenusRepository(source), GenusRepository(target))
        case .species:
            try applyModel(id, SpeciesRepository(source), SpeciesRepository(target))
        case .cultivar:
            try applyModel(id, CultivarRepository(source), CultivarRepository(target))
        case .pest:
            try applyModel(id, PestRepository(source), PestRepository(target))
        case .disease:
            try applyModel(id, DiseaseRepository(source), DiseaseRepository(target))
        case .pathogen:
            try applyModel(id, PathogenRepository(source), PathogenRepository(target))
        case .environmentalCondition:
            try applyModel(
                id, EnvironmentalConditionRepository(source),
                EnvironmentalConditionRepository(target))
        default:
            return false
        }
        return true
    }

    private func applyGrowth(_ change: ChangeRecord) throws -> Bool {
        let id = change.entityID
        switch change.kind {
        case .seedLot:
            try applyModel(id, SeedLotRepository(source), SeedLotRepository(target))
        case .starterBatch:
            try applyModel(id, StarterBatchRepository(source), StarterBatchRepository(target))
        case .planting:
            try applyModel(id, PlantingRepository(source), PlantingRepository(target))
        case .observation:
            if let model = try sourceObservations.fetch(id: Observation.ID(rawValue: id)) {
                try targetObservations.apply(model)
            }
        case .observationPhoto:
            if let photo = try sourceObservations.photoRecord(id: id) {
                try targetObservations.applyPhoto(photo)
            }
        default:
            return false
        }
        return true
    }

    private func applyOutcome(_ change: ChangeRecord) throws {
        let id = change.entityID
        switch change.kind {
        case .harvest:
            try applyModel(id, HarvestRepository(source), HarvestRepository(target))
        case .task:
            try applyModel(id, GardenTaskRepository(source), GardenTaskRepository(target))
        case .dailyWeather:
            try applyWeather(id)
        default:
            break
        }
    }

    private func applyWeather(_ key: String) throws {
        guard let separator = key.lastIndex(of: "/"),
            let day = DayStamp(storageValue: String(key[key.index(after: separator)...]))
        else {
            throw ChangeReplayError.malformedWeatherKey(key)
        }
        let propertyID = Property.ID(rawValue: String(key[..<separator]))
        if let record = try DailyWeatherRepository(source).record(for: propertyID, on: day) {
            try DailyWeatherRepository(target).upsert(record)
        }
    }

    private func locatedInParent(of id: String) throws -> String {
        let parent = try source.writer.read { db in
            try GraphStore.outgoing(from: id, via: .locatedIn, in: db).first?.target.id
        }
        guard let parent else {
            throw ChangeReplayError.orphanedStructure(id)
        }
        return parent
    }
}

extension ChangeReplayer {
    private func remove(_ change: ChangeRecord) throws {
        if try removeStructure(change) {
            return
        }
        if try removeTaxon(change) {
            return
        }
        try removeGrowth(change)
    }

    private func removeStructure(_ change: ChangeRecord) throws -> Bool {
        let structures = GardenStructureRepository(target)
        let id = change.entityID
        switch change.kind {
        case .property:
            try structures.deleteProperty(Property.ID(rawValue: id))
        case .garden:
            try structures.deleteGarden(Garden.ID(rawValue: id))
        case .growingArea:
            try structures.deleteGrowingArea(GrowingArea.ID(rawValue: id))
        case .bed:
            try structures.deleteBed(Bed.ID(rawValue: id))
        default:
            return false
        }
        return true
    }

    private func removeTaxon(_ change: ChangeRecord) throws -> Bool {
        let id = change.entityID
        switch change.kind {
        case .plantFamily:
            _ = try PlantFamilyRepository(target).delete(id: PlantFamily.ID(rawValue: id))
        case .genus:
            _ = try GenusRepository(target).delete(id: Genus.ID(rawValue: id))
        case .species:
            _ = try SpeciesRepository(target).delete(id: Species.ID(rawValue: id))
        case .cultivar:
            _ = try CultivarRepository(target).delete(id: Cultivar.ID(rawValue: id))
        case .pest:
            _ = try PestRepository(target).delete(id: Pest.ID(rawValue: id))
        case .disease:
            _ = try DiseaseRepository(target).delete(id: Disease.ID(rawValue: id))
        case .pathogen:
            _ = try PathogenRepository(target).delete(id: Pathogen.ID(rawValue: id))
        case .environmentalCondition:
            _ = try EnvironmentalConditionRepository(target).delete(
                id: EnvironmentalCondition.ID(rawValue: id))
        default:
            return false
        }
        return true
    }

    private func removeGrowth(_ change: ChangeRecord) throws {
        let id = change.entityID
        switch change.kind {
        case .seedLot:
            _ = try SeedLotRepository(target).delete(id: SeedLot.ID(rawValue: id))
        case .starterBatch:
            _ = try StarterBatchRepository(target).delete(id: StarterBatch.ID(rawValue: id))
        case .planting:
            _ = try PlantingRepository(target).delete(id: Planting.ID(rawValue: id))
        case .observation:
            _ = try targetObservations.delete(id: Observation.ID(rawValue: id))
        case .observationPhoto:
            try target.writer.write { db in
                _ = try ObservationPhotoRecord.deleteOne(db, key: id)
            }
        case .harvest:
            _ = try HarvestRepository(target).delete(id: Harvest.ID(rawValue: id))
        case .task:
            _ = try GardenTaskRepository(target).delete(id: GardenTask.ID(rawValue: id))
        default:
            break
        }
    }
}

private protocol ReplayableRepository {
    associatedtype Model
    associatedtype Identifier: RawRepresentable where Identifier.RawValue == String
    func fetch(id: Identifier) throws -> Model?
    func apply(_ model: Model) throws
}

extension ChangeReplayer {
    fileprivate func applyModel<Origin: ReplayableRepository, Destination: ReplayableRepository>(
        _ id: String,
        _ origin: Origin,
        _ destination: Destination
    ) throws where Origin.Model == Destination.Model, Origin.Identifier == Destination.Identifier {
        guard let identifier = Origin.Identifier(rawValue: id) else {
            return
        }
        if let model = try origin.fetch(id: identifier) {
            try destination.apply(model)
        }
    }
}

extension PlantFamilyRepository: ReplayableRepository {}
extension GenusRepository: ReplayableRepository {}
extension SpeciesRepository: ReplayableRepository {}
extension CultivarRepository: ReplayableRepository {}
extension PestRepository: ReplayableRepository {}
extension DiseaseRepository: ReplayableRepository {}
extension PathogenRepository: ReplayableRepository {}
extension EnvironmentalConditionRepository: ReplayableRepository {}
extension SeedLotRepository: ReplayableRepository {}
extension StarterBatchRepository: ReplayableRepository {}
extension PlantingRepository: ReplayableRepository {}
extension HarvestRepository: ReplayableRepository {}
extension GardenTaskRepository: ReplayableRepository {}
