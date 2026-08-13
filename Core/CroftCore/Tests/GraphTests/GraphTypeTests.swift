import Graph
import Testing

struct RelationshipTypeTests {
    @Test func rawValuesAreStableStrings() {
        #expect(RelationshipType.susceptibleTo.rawValue == "SUSCEPTIBLE_TO")
        #expect(RelationshipType.hostOf.rawValue == "HOST_OF")
        #expect(RelationshipType.companionWith.rawValue == "COMPANION_WITH")
        #expect(RelationshipType.locatedIn.rawValue == "LOCATED_IN")
        #expect(RelationshipType.parasitizedBy.rawValue == "PARASITIZED_BY")
        #expect(RelationshipType.predatedBy.rawValue == "PREDATED_BY")
        #expect(RelationshipType.causedBy.rawValue == "CAUSED_BY")
        #expect(RelationshipType.favoredBy.rawValue == "FAVORED_BY")
        #expect(RelationshipType.lotOf.rawValue == "LOT_OF")
        #expect(RelationshipType.sownFrom.rawValue == "SOWN_FROM")
        #expect(RelationshipType.observedOn.rawValue == "OBSERVED_ON")
    }

    @Test(arguments: RelationshipType.allCases)
    func roundTripsThroughRawValue(type: RelationshipType) {
        #expect(RelationshipType(rawValue: type.rawValue) == type)
    }

    @Test func deleteRulesAreDecidedPerType() {
        #expect(RelationshipType.susceptibleTo.deleteRule == .cascade)
        #expect(RelationshipType.hostOf.deleteRule == .cascade)
        #expect(RelationshipType.companionWith.deleteRule == .cascade)
        #expect(RelationshipType.locatedIn.deleteRule == .restrictTarget)
        #expect(RelationshipType.parasitizedBy.deleteRule == .cascade)
        #expect(RelationshipType.predatedBy.deleteRule == .cascade)
        #expect(RelationshipType.causedBy.deleteRule == .cascade)
        #expect(RelationshipType.favoredBy.deleteRule == .cascade)
        #expect(RelationshipType.lotOf.deleteRule == .cascade)
        #expect(RelationshipType.sownFrom.deleteRule == .cascade)
        #expect(RelationshipType.observedOn.deleteRule == .restrictTarget)
    }
}

struct EntityTypeTests {
    @Test func rawValuesAreStableStrings() {
        #expect(EntityType.plant.rawValue == "plant")
        #expect(EntityType.pest.rawValue == "pest")
        #expect(EntityType.disease.rawValue == "disease")
        #expect(EntityType.seedLot.rawValue == "seed_lot")
        #expect(EntityType.planting.rawValue == "planting")
        #expect(EntityType.property.rawValue == "property")
        #expect(EntityType.garden.rawValue == "garden")
        #expect(EntityType.growingArea.rawValue == "growing_area")
        #expect(EntityType.bed.rawValue == "bed")
        #expect(EntityType.pathogen.rawValue == "pathogen")
        #expect(EntityType.environmentalCondition.rawValue == "environmental_condition")
        #expect(EntityType.starterBatch.rawValue == "starter_batch")
        #expect(EntityType.observation.rawValue == "observation")
    }

    @Test(arguments: EntityType.allCases)
    func roundTripsThroughRawValue(type: EntityType) {
        #expect(EntityType(rawValue: type.rawValue) == type)
    }

    @Test(arguments: SourceType.allCases)
    func sourceTypeRoundTripsThroughRawValue(type: SourceType) {
        #expect(SourceType(rawValue: type.rawValue) == type)
    }
}
