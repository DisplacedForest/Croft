public enum ImageKind: String, CaseIterable, Sendable {
    case catalog
    case organism
    case symptom
    case damage
    case frass
    case eggMass = "egg_mass"
    case lifecycleStage = "lifecycle_stage"

    public enum RelatedRule: Sendable {
        case forbidden
        case required
        case optional
    }

    public var allowedOwners: Set<PlantImageInput.OwnerKind> {
        switch self {
        case .catalog: [.species, .cultivar]
        case .organism: [.pest, .disease]
        case .symptom: [.disease]
        case .damage, .frass, .eggMass, .lifecycleStage: [.pest]
        }
    }

    public var relatedRule: RelatedRule {
        switch self {
        case .catalog, .organism: .forbidden
        case .symptom, .damage, .frass, .eggMass: .required
        case .lifecycleStage: .optional
        }
    }

    public var isHostSpecific: Bool {
        relatedRule != .forbidden
    }
}

extension PlantImageInput.OwnerKind {
    public var isThreat: Bool {
        self == .pest || self == .disease
    }
}
