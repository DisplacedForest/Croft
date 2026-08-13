import Foundation

public typealias GardenTaskID = PropagationID<GardenTask>

public enum GardenTaskType: String, CaseIterable, Codable, Hashable, Sendable {
    case water
    case fertilize
    case prune
    case trellis
    case thin
    case transplant
    case inspect
    case harvest
    case treat
    case other
}

public enum GardenTaskTarget: Hashable, Sendable, Codable {
    case garden(Garden.ID)
    case bed(Bed.ID)
    case planting(Planting.ID)
}

public struct GardenTask: Equatable, Sendable, Codable {
    public typealias ID = GardenTaskID

    public var id: ID
    public var type: GardenTaskType
    public var customType: String?
    public var title: String
    public var notes: String?
    public var dueOn: Date?
    public var completed: Bool
    public var completedOn: Date?
    public var target: GardenTaskTarget?

    public init(
        id: ID = .generate(),
        type: GardenTaskType,
        customType: String? = nil,
        title: String,
        notes: String? = nil,
        dueOn: Date? = nil,
        completed: Bool = false,
        completedOn: Date? = nil,
        target: GardenTaskTarget? = nil
    ) {
        self.id = id
        self.type = type
        self.customType = customType
        self.title = title
        self.notes = notes
        self.dueOn = dueOn
        self.completed = completed
        self.completedOn = completedOn
        self.target = target
    }
}
