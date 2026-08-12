import Domain
import GRDB
import Graph

protocol StructureRecord: Codable, FetchableRecord, PersistableRecord, GraphEntity {
    var id: String { get }
    var name: String { get set }
    var archived: Bool { get set }
}

extension StructureRecord {
    var entityID: String { id }
}

struct PropertyRecord: StructureRecord {
    static let databaseTableName = "property"
    static var entityType: EntityType { .property }

    var id: String
    var name: String
    var notes: String?
    var archived: Bool

    init(_ model: Property) {
        id = model.id.rawValue
        name = model.name
        notes = model.notes
        archived = model.isArchived
    }

    func model() -> Property {
        Property(
            id: Property.ID(rawValue: id),
            name: name,
            notes: notes,
            isArchived: archived
        )
    }
}

struct GardenRecord: StructureRecord {
    static let databaseTableName = "garden"
    static var entityType: EntityType { .garden }

    var id: String
    var name: String
    var notes: String?
    var archived: Bool

    init(_ model: Garden) {
        id = model.id.rawValue
        name = model.name
        notes = model.notes
        archived = model.isArchived
    }

    func model() -> Garden {
        Garden(
            id: Garden.ID(rawValue: id),
            name: name,
            notes: notes,
            isArchived: archived
        )
    }
}

struct GrowingAreaRecord: StructureRecord {
    static let databaseTableName = "growing_area"
    static var entityType: EntityType { .growingArea }

    var id: String
    var name: String
    var notes: String?
    var archived: Bool

    init(_ model: GrowingArea) {
        id = model.id.rawValue
        name = model.name
        notes = model.notes
        archived = model.isArchived
    }

    func model() -> GrowingArea {
        GrowingArea(
            id: GrowingArea.ID(rawValue: id),
            name: name,
            notes: notes,
            isArchived: archived
        )
    }
}

struct BedRecord: StructureRecord {
    static let databaseTableName = "bed"
    static var entityType: EntityType { .bed }

    var id: String
    var name: String
    var kind: String
    var notes: String?
    var archived: Bool

    init(_ model: Bed) {
        id = model.id.rawValue
        name = model.name
        kind = model.kind.rawValue
        notes = model.notes
        archived = model.isArchived
    }

    func model() throws -> Bed {
        guard let bedKind = BedKind(rawValue: kind) else {
            throw GardenStructureError.unknownBedKind(kind)
        }
        return Bed(
            id: Bed.ID(rawValue: id),
            name: name,
            kind: bedKind,
            notes: notes,
            isArchived: archived
        )
    }
}
