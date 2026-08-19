import Domain
import GRDB
import Graph

public enum GardenStructureError: Error, Hashable {
    case parentNotFound(String)
    case structureNotFound(String)
    case unknownBedKind(String)
    case invalidPropertyDetails(String)
}

public enum BedParent: Hashable, Sendable {
    case garden(Garden.ID)
    case growingArea(GrowingArea.ID)
}

public struct GardenStructureRepository: Sendable {
    private let writer: any DatabaseWriter
    private let changes: ChangeLogger

    public init(_ database: AppDatabase) {
        writer = database.writer
        changes = ChangeLogger(database)
    }

    public func create(_ property: Property) throws {
        try writer.write { db in
            let record = PropertyRecord(property)
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
            try changes.record(.property, record.id, .create, in: db)
        }
    }

    public func create(_ garden: Garden, in propertyID: Property.ID) throws {
        try writer.write { db in
            let parent = try parentRef(PropertyRecord.self, propertyID.rawValue, in: db)
            try createChild(GardenRecord(garden), under: parent, in: db)
        }
    }

    public func create(_ area: GrowingArea, in gardenID: Garden.ID) throws {
        try writer.write { db in
            let parent = try parentRef(GardenRecord.self, gardenID.rawValue, in: db)
            try createChild(GrowingAreaRecord(area), under: parent, in: db)
        }
    }

    public func create(_ bed: Bed, in parent: BedParent) throws {
        try writer.write { db in
            let parent = try ref(of: parent, in: db)
            try createChild(BedRecord(bed), under: parent, in: db)
        }
    }

    public func renameProperty(_ id: Property.ID, to name: String) throws {
        try rename(PropertyRecord.self, id.rawValue, to: name)
    }

    public func renameGarden(_ id: Garden.ID, to name: String) throws {
        try rename(GardenRecord.self, id.rawValue, to: name)
    }

    public func renameGrowingArea(_ id: GrowingArea.ID, to name: String) throws {
        try rename(GrowingAreaRecord.self, id.rawValue, to: name)
    }

    public func renameBed(_ id: Bed.ID, to name: String) throws {
        try rename(BedRecord.self, id.rawValue, to: name)
    }

    public func moveGarden(_ id: Garden.ID, to propertyID: Property.ID) throws {
        try writer.write { db in
            let parent = try parentRef(PropertyRecord.self, propertyID.rawValue, in: db)
            try move(GardenRecord.self, id.rawValue, under: parent, in: db)
        }
    }

    public func moveGrowingArea(_ id: GrowingArea.ID, to gardenID: Garden.ID) throws {
        try writer.write { db in
            let parent = try parentRef(GardenRecord.self, gardenID.rawValue, in: db)
            try move(GrowingAreaRecord.self, id.rawValue, under: parent, in: db)
        }
    }

    public func moveBed(_ id: Bed.ID, to parent: BedParent) throws {
        try writer.write { db in
            let parent = try ref(of: parent, in: db)
            try move(BedRecord.self, id.rawValue, under: parent, in: db)
        }
    }

    public func setPropertyArchived(_ id: Property.ID, _ archived: Bool) throws {
        try setArchived(PropertyRecord.self, id.rawValue, archived)
    }

    public func setGardenArchived(_ id: Garden.ID, _ archived: Bool) throws {
        try setArchived(GardenRecord.self, id.rawValue, archived)
    }

    public func setGrowingAreaArchived(_ id: GrowingArea.ID, _ archived: Bool) throws {
        try setArchived(GrowingAreaRecord.self, id.rawValue, archived)
    }

    public func setBedArchived(_ id: Bed.ID, _ archived: Bool) throws {
        try setArchived(BedRecord.self, id.rawValue, archived)
    }

    public func deleteProperty(_ id: Property.ID) throws {
        try delete(PropertyRecord.self, id.rawValue)
    }

    public func deleteGarden(_ id: Garden.ID) throws {
        try delete(GardenRecord.self, id.rawValue)
    }

    public func deleteGrowingArea(_ id: GrowingArea.ID) throws {
        try delete(GrowingAreaRecord.self, id.rawValue)
    }

    public func deleteBed(_ id: Bed.ID) throws {
        try delete(BedRecord.self, id.rawValue)
    }

    public func properties(includeArchived: Bool = false) throws -> [Property] {
        try writer.read { db in
            var request = PropertyRecord.order(Column("name"))
            if !includeArchived {
                request = request.filter(Column("archived") == false)
            }
            return try request.fetchAll(db).map { try $0.model() }
        }
    }

    public func gardens(
        in propertyID: Property.ID,
        includeArchived: Bool = false
    ) throws -> [Garden] {
        try writer.read { db in
            try children(
                GardenRecord.self, of: propertyID.rawValue,
                includeArchived: includeArchived, in: db
            )
            .map { $0.model() }
        }
    }

    public func growingAreas(
        in gardenID: Garden.ID,
        includeArchived: Bool = false
    ) throws -> [GrowingArea] {
        try writer.read { db in
            try children(
                GrowingAreaRecord.self, of: gardenID.rawValue,
                includeArchived: includeArchived, in: db
            )
            .map { $0.model() }
        }
    }

    public func beds(in parent: BedParent, includeArchived: Bool = false) throws -> [Bed] {
        try writer.read { db in
            let parentID: String =
                switch parent {
                case .garden(let id): id.rawValue
                case .growingArea(let id): id.rawValue
                }
            return try children(
                BedRecord.self, of: parentID,
                includeArchived: includeArchived, in: db
            )
            .map { try $0.model() }
        }
    }

    private func parentRef<Record: StructureRecord>(
        _ record: Record.Type,
        _ id: String,
        in db: Database
    ) throws -> EntityRef {
        guard let found = try Record.fetchOne(db, key: id) else {
            throw GardenStructureError.parentNotFound(id)
        }
        return found.entityRef
    }

    private func ref(of parent: BedParent, in db: Database) throws -> EntityRef {
        switch parent {
        case .garden(let id):
            try parentRef(GardenRecord.self, id.rawValue, in: db)
        case .growingArea(let id):
            try parentRef(GrowingAreaRecord.self, id.rawValue, in: db)
        }
    }

    private func createChild<Record: StructureRecord>(
        _ record: Record,
        under parent: EntityRef,
        in db: Database
    ) throws {
        try record.insert(db)
        try GraphStore.register(record.entityRef, in: db)
        try GraphStore.relate(from: record.entityRef, .locatedIn, to: parent, in: db)
        try changes.record(Record.changeKind, record.id, .create, in: db)
    }

    private func rename<Record: StructureRecord>(
        _ record: Record.Type,
        _ id: String,
        to name: String
    ) throws {
        try writer.write { db in
            guard var found = try Record.fetchOne(db, key: id) else {
                throw GardenStructureError.structureNotFound(id)
            }
            found.name = name
            try found.update(db)
            try changes.record(Record.changeKind, found.id, .update, in: db)
        }
    }

    private func move<Record: StructureRecord>(
        _ record: Record.Type,
        _ id: String,
        under parent: EntityRef,
        in db: Database
    ) throws {
        guard let found = try Record.fetchOne(db, key: id) else {
            throw GardenStructureError.structureNotFound(id)
        }
        for edge in try GraphStore.outgoing(from: id, via: .locatedIn, in: db) {
            try GraphStore.unrelate(edgeID: edge.id, in: db)
        }
        try GraphStore.relate(from: found.entityRef, .locatedIn, to: parent, in: db)
        try changes.record(Record.changeKind, found.id, .update, in: db)
    }

    private func setArchived<Record: StructureRecord>(
        _ record: Record.Type,
        _ id: String,
        _ archived: Bool
    ) throws {
        try writer.write { db in
            guard var found = try Record.fetchOne(db, key: id) else {
                throw GardenStructureError.structureNotFound(id)
            }
            found.archived = archived
            try found.update(db)
            try changes.record(Record.changeKind, found.id, .update, in: db)
        }
    }

    private func delete<Record: StructureRecord>(
        _ record: Record.Type,
        _ id: String
    ) throws {
        try writer.write { db in
            try GraphStore.deleteEntity(id, in: db)
            if try Record.deleteOne(db, key: id) {
                try changes.record(Record.changeKind, id, .delete, in: db)
            }
        }
    }

    private func children<Record: StructureRecord>(
        _ record: Record.Type,
        of parentID: String,
        includeArchived: Bool,
        in db: Database
    ) throws -> [Record] {
        let refs = try GraphStore.incoming(to: parentID, via: .locatedIn, in: db)
            .map(\.source)
        return try GraphStore.resolve(refs, as: Record.self, in: db)
            .filter { includeArchived || !$0.archived }
            .sorted { $0.name < $1.name }
    }
}

extension GardenStructureRepository {
    public func property(id: Property.ID) throws -> Property? {
        try writer.read { db in
            try PropertyRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func updatePropertyDetails(
        _ id: Property.ID,
        location: GeoCoordinate?,
        hardinessZone: Int?,
        lastFrost: MonthDay?,
        firstFrost: MonthDay?
    ) throws {
        try writer.write { db in
            guard var found = try PropertyRecord.fetchOne(db, key: id.rawValue) else {
                throw GardenStructureError.structureNotFound(id.rawValue)
            }
            found.latitude = location?.latitude
            found.longitude = location?.longitude
            found.hardinessZone = hardinessZone
            found.lastFrostMonth = lastFrost?.month
            found.lastFrostDay = lastFrost?.day
            found.firstFrostMonth = firstFrost?.month
            found.firstFrostDay = firstFrost?.day
            try found.update(db)
            try changes.record(.property, found.id, .update, in: db)
        }
    }

    public func garden(id: Garden.ID) throws -> Garden? {
        try writer.read { db in
            try GardenRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func growingArea(id: GrowingArea.ID) throws -> GrowingArea? {
        try writer.read { db in
            try GrowingAreaRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func bed(id: Bed.ID) throws -> Bed? {
        try writer.read { db in
            try BedRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func parent(ofBed id: Bed.ID) throws -> BedParent? {
        try writer.read { db in
            guard
                let edge = try GraphStore.outgoing(from: id.rawValue, via: .locatedIn, in: db).first
            else {
                return nil
            }
            return switch edge.target.type {
            case .garden: .garden(Garden.ID(rawValue: edge.target.id))
            case .growingArea: .growingArea(GrowingArea.ID(rawValue: edge.target.id))
            default: nil
            }
        }
    }
}

extension GardenStructureRepository {
    public func apply(_ property: Property) throws {
        try writer.write { db in
            let record = PropertyRecord(property)
            if try PropertyRecord.fetchOne(db, key: record.id) != nil {
                try record.update(db)
                try changes.record(.property, record.id, .update, in: db)
            } else {
                try record.insert(db)
                try GraphStore.register(record.entityRef, in: db)
                try changes.record(.property, record.id, .create, in: db)
            }
        }
    }

    public func apply(_ garden: Garden, in propertyID: Property.ID) throws {
        try writer.write { db in
            let parent = try parentRef(PropertyRecord.self, propertyID.rawValue, in: db)
            try applyChild(GardenRecord(garden), under: parent, in: db)
        }
    }

    public func apply(_ area: GrowingArea, in gardenID: Garden.ID) throws {
        try writer.write { db in
            let parent = try parentRef(GardenRecord.self, gardenID.rawValue, in: db)
            try applyChild(GrowingAreaRecord(area), under: parent, in: db)
        }
    }

    public func apply(_ bed: Bed, in parent: BedParent) throws {
        try writer.write { db in
            let parent = try ref(of: parent, in: db)
            try applyChild(BedRecord(bed), under: parent, in: db)
        }
    }

    private func applyChild<Record: StructureRecord>(
        _ record: Record,
        under parent: EntityRef,
        in db: Database
    ) throws {
        guard try Record.fetchOne(db, key: record.id) != nil else {
            try createChild(record, under: parent, in: db)
            return
        }
        try record.update(db)
        for edge in try GraphStore.outgoing(from: record.id, via: .locatedIn, in: db) {
            try GraphStore.unrelate(edgeID: edge.id, in: db)
        }
        try GraphStore.relate(from: record.entityRef, .locatedIn, to: parent, in: db)
        try changes.record(Record.changeKind, record.id, .update, in: db)
    }
}
