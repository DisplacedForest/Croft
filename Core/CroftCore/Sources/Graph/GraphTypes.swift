public enum EntityType: String, CaseIterable, Codable, Hashable, Sendable {
    case plant
    case pest
    case disease
    case seedLot = "seed_lot"
    case planting
    case property
    case garden
    case growingArea = "growing_area"
    case bed
    case pathogen
    case environmentalCondition = "environmental_condition"
    case starterBatch = "starter_batch"
    case observation
    case harvest
}

public enum RelationshipType: String, CaseIterable, Codable, Hashable, Sendable {
    case susceptibleTo = "SUSCEPTIBLE_TO"
    case hostOf = "HOST_OF"
    case companionWith = "COMPANION_WITH"
    case locatedIn = "LOCATED_IN"
    case parasitizedBy = "PARASITIZED_BY"
    case predatedBy = "PREDATED_BY"
    case antagonisticTo = "ANTAGONISTIC_TO"
    case rotateAwayFrom = "ROTATE_AWAY_FROM"
    case causedBy = "CAUSED_BY"
    case favoredBy = "FAVORED_BY"
    case lotOf = "LOT_OF"
    case sownFrom = "SOWN_FROM"
    case instanceOf = "INSTANCE_OF"
    case plantedFrom = "PLANTED_FROM"
    case vectorOf = "VECTOR_OF"
    case resistantTo = "RESISTANT_TO"
    case observedOn = "OBSERVED_ON"
    case harvestedFrom = "HARVESTED_FROM"

    public enum DeleteRule: Hashable, Sendable {
        case cascade
        case restrictTarget
    }

    public var deleteRule: DeleteRule {
        switch self {
        case .susceptibleTo, .hostOf, .companionWith, .parasitizedBy, .predatedBy,
            .antagonisticTo, .rotateAwayFrom, .causedBy, .favoredBy, .lotOf, .sownFrom,
            .instanceOf, .plantedFrom, .vectorOf, .resistantTo:
            .cascade
        case .locatedIn, .observedOn, .harvestedFrom:
            .restrictTarget
        }
    }

    public var requiresProvenance: Bool {
        switch self {
        case .companionWith, .antagonisticTo, .rotateAwayFrom:
            true
        case .susceptibleTo, .hostOf, .locatedIn, .parasitizedBy, .predatedBy,
            .causedBy, .favoredBy, .lotOf, .sownFrom, .instanceOf, .plantedFrom,
            .vectorOf, .resistantTo, .observedOn, .harvestedFrom:
            false
        }
    }

    public var defaultConfidence: Double? {
        switch self {
        case .companionWith:
            0.3
        case .susceptibleTo, .hostOf, .locatedIn, .parasitizedBy, .predatedBy,
            .antagonisticTo, .rotateAwayFrom, .causedBy, .favoredBy, .lotOf, .sownFrom,
            .instanceOf, .plantedFrom, .vectorOf, .resistantTo, .observedOn, .harvestedFrom:
            nil
        }
    }
}

public enum SourceType: String, CaseIterable, Codable, Hashable, Sendable {
    case observation
    case reference
    case imported
    case inferred
}

public struct Provenance: Hashable, Sendable {
    public var source: String?
    public var sourceType: SourceType?
    public var confidence: Double?
    public var notes: String?

    public init(
        source: String? = nil,
        sourceType: SourceType? = nil,
        confidence: Double? = nil,
        notes: String? = nil
    ) {
        self.source = source
        self.sourceType = sourceType
        self.confidence = confidence
        self.notes = notes
    }
}

public struct EntityRef: Hashable, Sendable {
    public let id: String
    public let type: EntityType

    public init(id: String, type: EntityType) {
        self.id = id
        self.type = type
    }
}

public struct Edge: Hashable, Sendable {
    public let id: String
    public let source: EntityRef
    public let type: RelationshipType
    public let target: EntityRef
    public let provenance: Provenance
}

public protocol GraphEntity {
    static var entityType: EntityType { get }
    var entityID: String { get }
}

extension GraphEntity {
    public var entityRef: EntityRef {
        EntityRef(id: entityID, type: Self.entityType)
    }
}

public enum GraphError: Error, Hashable {
    case unknownEntityType(String)
    case unknownRelationshipType(String)
    case unknownSourceType(String)
    case unresolvedEntity(String)
    case entityTypeMismatch(id: String, stored: EntityType, requested: EntityType)
    case missingProvenance(RelationshipType)
}
