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

    static var changeKind: ChangeKind {
        switch entityType {
        case .garden: .garden
        case .growingArea: .growingArea
        case .bed: .bed
        default: .property
        }
    }
}

struct PropertyRecord: StructureRecord {
    static let databaseTableName = "property"
    static var entityType: EntityType { .property }

    var id: String
    var name: String
    var notes: String?
    var archived: Bool
    var latitude: Double?
    var longitude: Double?
    var hardinessZone: String?
    var lastFrostMonth: Int?
    var lastFrostDay: Int?
    var firstFrostMonth: Int?
    var firstFrostDay: Int?
    var zoneSource: String
    var frostDatesSource: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case notes
        case archived
        case latitude
        case longitude
        case hardinessZone = "hardiness_zone"
        case lastFrostMonth = "last_frost_month"
        case lastFrostDay = "last_frost_day"
        case firstFrostMonth = "first_frost_month"
        case firstFrostDay = "first_frost_day"
        case zoneSource = "zone_source"
        case frostDatesSource = "frost_dates_source"
    }

    init(_ model: Property) {
        id = model.id.rawValue
        name = model.name
        notes = model.notes
        archived = model.isArchived
        latitude = model.location?.latitude
        longitude = model.location?.longitude
        hardinessZone = model.hardinessZone?.description
        lastFrostMonth = model.lastFrost?.month
        lastFrostDay = model.lastFrost?.day
        firstFrostMonth = model.firstFrost?.month
        firstFrostDay = model.firstFrost?.day
        zoneSource = model.zoneSource.rawValue
        frostDatesSource = model.frostDatesSource.rawValue
    }

    func model() throws -> Property {
        Property(
            id: Property.ID(rawValue: id),
            name: name,
            notes: notes,
            isArchived: archived,
            location: try coordinate(),
            hardinessZone: try zone(),
            lastFrost: try frost(lastFrostMonth, lastFrostDay, column: "last_frost"),
            firstFrost: try frost(firstFrostMonth, firstFrostDay, column: "first_frost"),
            zoneSource: try source(zoneSource, column: "zone_source"),
            frostDatesSource: try source(frostDatesSource, column: "frost_dates_source")
        )
    }

    private func source(_ raw: String, column: String) throws -> ClimateSource {
        guard let parsed = ClimateSource(rawValue: raw) else {
            throw GardenStructureError.invalidPropertyDetails("\(column) \(raw)")
        }
        return parsed
    }

    private func zone() throws -> HardinessZone? {
        guard let hardinessZone else {
            return nil
        }
        guard let parsed = HardinessZone(parsing: hardinessZone) else {
            throw GardenStructureError.invalidPropertyDetails("hardiness zone \(hardinessZone)")
        }
        return parsed
    }

    private func coordinate() throws -> GeoCoordinate? {
        switch (latitude, longitude) {
        case (nil, nil):
            return nil
        case (let lat?, let lon?):
            guard let coordinate = GeoCoordinate(latitude: lat, longitude: lon) else {
                throw GardenStructureError.invalidPropertyDetails("coordinate \(lat), \(lon)")
            }
            return coordinate
        default:
            throw GardenStructureError.invalidPropertyDetails("unpaired coordinate")
        }
    }

    private func frost(_ month: Int?, _ day: Int?, column: String) throws -> MonthDay? {
        switch (month, day) {
        case (nil, nil):
            return nil
        case (let month?, let day?):
            guard let monthDay = MonthDay(month: month, day: day) else {
                throw GardenStructureError.invalidPropertyDetails("\(column) \(month)-\(day)")
            }
            return monthDay
        default:
            throw GardenStructureError.invalidPropertyDetails("unpaired \(column)")
        }
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
