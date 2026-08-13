import Domain
import Foundation

public struct PlantTaxonomy: Equatable, Sendable {
    public var familyName: String?
    public var genusName: String?
    public var scientificName: String
    public var cultivarName: String?

    public init(
        familyName: String? = nil,
        genusName: String? = nil,
        scientificName: String,
        cultivarName: String? = nil
    ) {
        self.familyName = familyName
        self.genusName = genusName
        self.scientificName = scientificName
        self.cultivarName = cultivarName
    }
}

public struct PlantThreat: Equatable, Hashable, Sendable, Identifiable {
    public enum Kind: Equatable, Hashable, Sendable {
        case pest
        case disease
    }

    public var id: String
    public var kind: Kind
    public var name: String
    public var agentName: String?
    public var summary: String?
    public var affectedParts: [PlantPart]

    public init(
        id: String,
        kind: Kind,
        name: String,
        agentName: String? = nil,
        summary: String? = nil,
        affectedParts: [PlantPart] = []
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.agentName = agentName
        self.summary = summary
        self.affectedParts = affectedParts
    }
}

public struct CurrentPlanting: Equatable, Sendable, Identifiable {
    public var id: String
    public var locationName: String?
    public var quantity: Int?
    public var status: PlantingStatus
    public var plantedOn: Date?
    public var expectedMaturityOn: Date?

    public init(
        id: String,
        locationName: String? = nil,
        quantity: Int? = nil,
        status: PlantingStatus,
        plantedOn: Date? = nil,
        expectedMaturityOn: Date? = nil
    ) {
        self.id = id
        self.locationName = locationName
        self.quantity = quantity
        self.status = status
        self.plantedOn = plantedOn
        self.expectedMaturityOn = expectedMaturityOn
    }
}

public struct ActivityEvent: Equatable, Sendable, Identifiable {
    public enum Kind: String, Equatable, Sendable {
        case planted
        case transplanted
        case finished
        case failed
    }

    public var id: String
    public var date: Date
    public var kind: Kind
    public var locationName: String?
    public var quantity: Int?

    public init(
        id: String,
        date: Date,
        kind: Kind,
        locationName: String? = nil,
        quantity: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.locationName = locationName
        self.quantity = quantity
    }
}

public struct PlantPage: Equatable, Sendable {
    public var identity: PlantIdentity
    public var displayName: String
    public var commonNames: [String]
    public var taxonomy: PlantTaxonomy
    public var conditions: GrowingConditions
    public var threats: [PlantThreat]
    public var currentPlantings: [CurrentPlanting]
    public var activity: [ActivityEvent]
    public var image: PlantImage?

    public init(
        identity: PlantIdentity,
        displayName: String,
        commonNames: [String] = [],
        taxonomy: PlantTaxonomy,
        conditions: GrowingConditions,
        threats: [PlantThreat] = [],
        currentPlantings: [CurrentPlanting] = [],
        activity: [ActivityEvent] = [],
        image: PlantImage? = nil
    ) {
        self.identity = identity
        self.displayName = displayName
        self.commonNames = commonNames
        self.taxonomy = taxonomy
        self.conditions = conditions
        self.threats = threats
        self.currentPlantings = currentPlantings
        self.activity = activity
        self.image = image
    }
}
