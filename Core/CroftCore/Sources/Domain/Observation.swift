import Foundation

public typealias ObservationID = PropagationID<Observation>

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
    public var growthState: String?
    public var symptoms: [String]
    public var measurements: [ObservationMeasurement]
    public var tags: [String]
    public var photos: [String]

    public init(
        id: ID = .generate(),
        target: ObservationTarget,
        observedAt: Date,
        notes: String? = nil,
        growthState: String? = nil,
        symptoms: [String] = [],
        measurements: [ObservationMeasurement] = [],
        tags: [String] = [],
        photos: [String] = []
    ) {
        self.id = id
        self.target = target
        self.observedAt = observedAt
        self.notes = notes
        self.growthState = growthState
        self.symptoms = symptoms
        self.measurements = measurements
        self.tags = tags
        self.photos = photos
    }
}
