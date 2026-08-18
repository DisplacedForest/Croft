import Foundation

public typealias ObservationID = PropagationID<Observation>

public enum LifecycleStage: String, CaseIterable, Codable, Hashable, Sendable {
    case germinated
    case transplanted
    case firstFlower = "first_flower"
    case firstFruitSet = "first_fruit_set"
    case pulled
}

public struct ObservationMeasurement: Hashable, Sendable, Codable {
    public var label: String
    public var value: Double
    public var unit: String

    public init(label: String, value: Double, unit: String) {
        self.label = label
        self.value = value
        self.unit = unit
    }
}

public enum ObservationTarget: Hashable, Sendable, Codable {
    case planting(Planting.ID)
    case plant(PlantIdentity)
    case bed(Bed.ID)
    case garden(Garden.ID)
}

public struct Observation: Equatable, Sendable, Codable {
    public typealias ID = ObservationID

    public var id: ID
    public var target: ObservationTarget
    public var observedAt: Date
    public var notes: String?
    public var stage: LifecycleStage?
    public var symptoms: [String]
    public var measurements: [ObservationMeasurement]
    public var tags: [String]
    public var photos: [String]

    public init(
        id: ID = .generate(),
        target: ObservationTarget,
        observedAt: Date,
        notes: String? = nil,
        stage: LifecycleStage? = nil,
        symptoms: [String] = [],
        measurements: [ObservationMeasurement] = [],
        tags: [String] = [],
        photos: [String] = []
    ) {
        self.id = id
        self.target = target
        self.observedAt = observedAt
        self.notes = notes
        self.stage = stage
        self.symptoms = symptoms
        self.measurements = measurements
        self.tags = tags
        self.photos = photos
    }
}
