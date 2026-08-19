import Domain
import Foundation
import GRDB
import Graph

public enum ObservationError: Error, Hashable {
    case observationNotFound(String)
    case malformedTarget(String)
}

public struct StageEvent: Equatable, Sendable {
    public let observationID: Observation.ID
    public let stage: LifecycleStage
    public let observedAt: Date

    public init(observationID: Observation.ID, stage: LifecycleStage, observedAt: Date) {
        self.observationID = observationID
        self.stage = stage
        self.observedAt = observedAt
    }
}

public struct ObservationRepository: Sendable {
    private let writer: any DatabaseWriter
    private let photoStore: PhotoStore
    private let changes: ChangeLogger

    public init(_ database: AppDatabase, photos: PhotoStore) {
        writer = database.writer
        photoStore = photos
        changes = ChangeLogger(database)
    }

    public func insert(_ observation: Observation) throws {
        let record = try ObservationRecord(observation)
        let target = try record.targetRef()
        try writer.write { db in
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
            try GraphStore.register(target, in: db)
            try GraphStore.relate(from: record.entityRef, .observedOn, to: target, in: db)
            try changes.record(.observation, record.id, .create, in: db)
        }
    }

    public func update(_ observation: Observation) throws {
        let record = try ObservationRecord(observation)
        let target = try record.targetRef()
        try writer.write { db in
            guard try ObservationRecord.fetchOne(db, key: record.id) != nil else {
                throw ObservationError.observationNotFound(record.id)
            }
            try record.update(db)
            try repoint(.observedOn, of: record.entityRef, to: target, in: db)
            try changes.record(.observation, record.id, .update, in: db)
        }
    }

    public func fetch(id: Observation.ID) throws -> Observation? {
        try writer.read { db in
            guard let record = try ObservationRecord.fetchOne(db, key: id.rawValue) else {
                return nil
            }
            return try models([record], in: db).first
        }
    }

    public func fetchAll() throws -> [Observation] {
        try writer.read { db in
            try models(
                try ObservationRecord
                    .order(Column("observed_at").desc, Column("id"))
                    .fetchAll(db),
                in: db
            )
        }
    }

    public func observations(on target: ObservationTarget) throws -> [Observation] {
        try writer.read { db in
            try models(
                try ObservationRecord
                    .filter(Self.column(for: target) == Self.identifier(of: target))
                    .order(Column("observed_at").desc, Column("id"))
                    .fetchAll(db),
                in: db
            )
        }
    }

    public func recent(limit: Int) throws -> [Observation] {
        try writer.read { db in
            try models(
                try ObservationRecord
                    .order(Column("observed_at").desc, Column("id"))
                    .limit(limit)
                    .fetchAll(db),
                in: db
            )
        }
    }

    public func addPhoto(_ data: Data, to id: Observation.ID) throws -> String {
        guard try exists(id) else {
            throw ObservationError.observationNotFound(id.rawValue)
        }
        let relativePath = try photoStore.add(data, forObservation: id)
        let record = ObservationPhotoRecord(
            id: UUID().uuidString,
            observationID: id.rawValue,
            relativePath: relativePath,
            createdAt: Date()
        )
        do {
            try writer.write { db in
                try record.insert(db)
                try changes.record(.observationPhoto, record.id, .create, in: db)
            }
        } catch {
            if let url = try? photoStore.url(forRelativePath: relativePath) {
                try? FileManager.default.removeItem(at: url)
            }
            throw error
        }
        return relativePath
    }

    public func photos(for id: Observation.ID) throws -> [String] {
        try writer.read { db in
            try Self.photoPaths(for: [id.rawValue], in: db)[id.rawValue] ?? []
        }
    }

    @discardableResult
    public func delete(id: Observation.ID) throws -> Bool {
        let deleted = try writer.write { db in
            try GraphStore.deleteEntity(id.rawValue, in: db)
            let removed = try ObservationRecord.deleteOne(db, key: id.rawValue)
            if removed {
                try changes.record(.observation, id.rawValue, .delete, in: db)
            }
            return removed
        }
        if deleted {
            try photoStore.removePhotos(forObservation: id)
        }
        return deleted
    }

    public func sweepOrphanedPhotos(graceInterval: TimeInterval = 3600) throws {
        let cutoff = Date(timeIntervalSinceNow: -graceInterval)
        let referenced = try writer.read { db -> [String: Set<String>] in
            let ids = try String.fetchAll(db, sql: "SELECT id FROM observation")
            let paths = try Self.photoPaths(for: ids, in: db)
            return Dictionary(uniqueKeysWithValues: ids.map { ($0, Set(paths[$0] ?? [])) })
        }
        for (id, paths) in referenced {
            try photoStore.sweepFiles(
                forObservation: Observation.ID(rawValue: id),
                keeping: paths,
                modifiedBefore: cutoff)
        }
        let candidates = try photoStore.orphanedIdentifiers(keeping: Set(referenced.keys))
        for candidate in candidates {
            let id = Observation.ID(rawValue: candidate)
            guard try !exists(id) else {
                continue
            }
            try photoStore.removePhotos(forObservation: id)
        }
    }

    private static func photoPaths(
        for ids: [String],
        in db: Database
    ) throws -> [String: [String]] {
        guard !ids.isEmpty else {
            return [:]
        }
        let records =
            try ObservationPhotoRecord
            .filter(ids.contains(Column("observation_id")))
            .order(Column("created_at"), Column("id"))
            .fetchAll(db)
        return Dictionary(grouping: records, by: \.observationID)
            .mapValues { $0.map(\.relativePath) }
    }

    private func models(_ records: [ObservationRecord], in db: Database) throws -> [Observation] {
        let paths = try Self.photoPaths(for: records.map(\.id), in: db)
        return try records.map { try $0.model(photos: paths[$0.id] ?? []) }
    }

    private static func column(for target: ObservationTarget) -> Column {
        switch target {
        case .planting:
            Column("planting_id")
        case .plant(.cultivar):
            Column("cultivar_id")
        case .plant(.species):
            Column("species_id")
        case .bed:
            Column("bed_id")
        case .garden:
            Column("garden_id")
        }
    }

    private static func identifier(of target: ObservationTarget) -> String {
        switch target {
        case .planting(let planting):
            planting.rawValue
        case .plant(.cultivar(let cultivar)):
            cultivar.rawValue
        case .plant(.species(let species)):
            species.rawValue
        case .bed(let bed):
            bed.rawValue
        case .garden(let garden):
            garden.rawValue
        }
    }

    private func exists(_ id: Observation.ID) throws -> Bool {
        try writer.read { db in
            try ObservationRecord.fetchOne(db, key: id.rawValue) != nil
        }
    }

    private func repoint(
        _ type: RelationshipType,
        of entity: EntityRef,
        to target: EntityRef,
        in db: Database
    ) throws {
        let edges = try GraphStore.outgoing(from: entity.id, via: type, in: db)
        guard edges.map(\.target.id) != [target.id] else {
            return
        }
        for edge in edges {
            try GraphStore.unrelate(edgeID: edge.id, in: db)
        }
        try GraphStore.register(target, in: db)
        try GraphStore.relate(from: entity, type, to: target, in: db)
    }
}

extension ObservationRepository {
    public func stageHistory(forPlanting id: Planting.ID) throws -> [StageEvent] {
        try writer.read { db in
            try Self.stageEvents(forPlanting: id, in: db)
        }
    }

    public func daysToGermination(forPlanting id: Planting.ID) throws -> Int? {
        try writer.read { db in
            guard
                let plantedOn = try Date.fetchOne(
                    db,
                    sql: "SELECT planted_on FROM planting WHERE id = ?",
                    arguments: [id.rawValue]),
                let germinated = try Self.stageEvents(forPlanting: id, in: db)
                    .first(where: { $0.stage == .germinated })
            else {
                return nil
            }
            return Self.wholeDays(from: plantedOn, to: germinated.observedAt)
        }
    }

    public func firstFlowerDate(forPlanting id: Planting.ID) throws -> Date? {
        try writer.read { db in
            try Self.stageEvents(forPlanting: id, in: db)
                .first(where: { $0.stage == .firstFlower })?
                .observedAt
        }
    }

    public func neverFruited(forPlanting id: Planting.ID) throws -> Bool {
        try writer.read { db in
            try !Self.stageEvents(forPlanting: id, in: db)
                .contains { $0.stage == .firstFruitSet }
        }
    }

    private static func stageEvents(
        forPlanting id: Planting.ID,
        in db: Database
    ) throws -> [StageEvent] {
        let decoder = TaxonomyRowDecoder(table: ObservationRecord.databaseTableName)
        let records =
            try ObservationRecord
            .filter(Column("planting_id") == id.rawValue)
            .filter(Column("stage") != nil)
            .order(Column("observed_at"), Column("id"))
            .fetchAll(db)
        return try records.compactMap { record in
            guard let raw = record.stage else {
                return nil
            }
            return StageEvent(
                observationID: Observation.ID(rawValue: record.id),
                stage: try decoder.enumValue(LifecycleStage.self, from: raw, column: "stage"),
                observedAt: record.observedAt
            )
        }
    }

    private static func wholeDays(from start: Date, to end: Date) -> Int? {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: end)
        ).day
    }
}

public struct ObservationPhoto: Equatable, Sendable {
    public let id: String
    public let observationID: Observation.ID
    public let relativePath: String
    public let createdAt: Date

    public init(id: String, observationID: Observation.ID, relativePath: String, createdAt: Date) {
        self.id = id
        self.observationID = observationID
        self.relativePath = relativePath
        self.createdAt = createdAt
    }
}

extension ObservationRepository {
    public func apply(_ observation: Observation) throws {
        if try fetch(id: observation.id) != nil {
            try update(observation)
        } else {
            try insert(observation)
        }
    }

    public func photoRecord(id: String) throws -> ObservationPhoto? {
        try writer.read { db in
            try ObservationPhotoRecord.fetchOne(db, key: id).map(Self.photo)
        }
    }

    public func applyPhoto(_ photo: ObservationPhoto) throws {
        let record = ObservationPhotoRecord(
            id: photo.id,
            observationID: photo.observationID.rawValue,
            relativePath: photo.relativePath,
            createdAt: photo.createdAt
        )
        try writer.write { db in
            let operation: ChangeOperation =
                try ObservationPhotoRecord.fetchOne(db, key: record.id) == nil
                ? .create : .update
            try record.save(db)
            try changes.record(.observationPhoto, record.id, operation, in: db)
        }
    }

    private static func photo(_ record: ObservationPhotoRecord) -> ObservationPhoto {
        ObservationPhoto(
            id: record.id,
            observationID: Observation.ID(rawValue: record.observationID),
            relativePath: record.relativePath,
            createdAt: record.createdAt
        )
    }
}
