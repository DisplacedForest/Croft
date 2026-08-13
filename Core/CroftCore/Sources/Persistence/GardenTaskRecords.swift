import Domain
import Foundation
import GRDB
import Graph

struct GardenTaskRecord: Codable, FetchableRecord, PersistableRecord, GraphEntity {
    static let databaseTableName = "task"
    static var entityType: EntityType { .task }

    var id: String
    var type: String
    var customType: String?
    var title: String
    var notes: String?
    var dueOn: Date?
    var completed: Bool
    var completedOn: Date?
    var gardenID: String?
    var bedID: String?
    var plantingID: String?

    var entityID: String { id }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case customType = "custom_type"
        case title
        case notes
        case dueOn = "due_on"
        case completed
        case completedOn = "completed_on"
        case gardenID = "garden_id"
        case bedID = "bed_id"
        case plantingID = "planting_id"
    }

    static func decodeType(_ raw: String) throws -> GardenTaskType {
        try TaxonomyRowDecoder(table: databaseTableName)
            .enumValue(GardenTaskType.self, from: raw, column: "type")
    }

    static func decodeType(
        _ raw: String,
        pairedWith customType: String?,
        rowID: String
    ) throws -> GardenTaskType {
        let decoded = try decodeType(raw)
        guard (decoded == .other) == (customType != nil) else {
            throw GardenTaskError.malformedType(rowID)
        }
        return decoded
    }

    init(_ task: GardenTask) {
        id = task.id.rawValue
        type = task.type.rawValue
        customType = task.customType
        title = task.title
        notes = task.notes
        dueOn = task.dueOn
        completed = task.completed
        completedOn = task.completedOn
        gardenID = nil
        bedID = nil
        plantingID = nil
        switch task.target {
        case .garden(let garden):
            gardenID = garden.rawValue
        case .bed(let bed):
            bedID = bed.rawValue
        case .planting(let planting):
            plantingID = planting.rawValue
        case nil:
            break
        }
    }

    func targetRef() throws -> EntityRef? {
        switch try target() {
        case .garden(let garden):
            EntityRef(id: garden.rawValue, type: .garden)
        case .bed(let bed):
            EntityRef(id: bed.rawValue, type: .bed)
        case .planting(let planting):
            EntityRef(id: planting.rawValue, type: .planting)
        case nil:
            nil
        }
    }

    func model() throws -> GardenTask {
        let decoded = try Self.decodeType(type, pairedWith: customType, rowID: id)
        guard completed == (completedOn != nil) else {
            throw GardenTaskError.malformedCompletion(id)
        }
        return GardenTask(
            id: GardenTask.ID(rawValue: id),
            type: decoded,
            customType: customType,
            title: title,
            notes: notes,
            dueOn: dueOn,
            completed: completed,
            completedOn: completedOn,
            target: try target()
        )
    }

    private func target() throws -> GardenTaskTarget? {
        let targets: [GardenTaskTarget] = [
            gardenID.map { .garden(Garden.ID(rawValue: $0)) },
            bedID.map { .bed(Bed.ID(rawValue: $0)) },
            plantingID.map { .planting(Planting.ID(rawValue: $0)) },
        ].compactMap { $0 }
        guard targets.count <= 1 else {
            throw GardenTaskError.malformedTarget(id)
        }
        return targets.first
    }
}
