import Graph
import Testing

struct ObservationRelationshipTypeTests {
    @Test func observationRawValuesAreStableStrings() {
        #expect(RelationshipType.observedOn.rawValue == "OBSERVED_ON")
        #expect(EntityType.observation.rawValue == "observation")
    }

    @Test func observedOnRoundTripsThroughRawValue() {
        #expect(RelationshipType(rawValue: "OBSERVED_ON") == .observedOn)
        #expect(EntityType(rawValue: "observation") == .observation)
    }

    @Test func observedOnRestrictsDeletingItsTarget() {
        #expect(RelationshipType.observedOn.deleteRule == .restrictTarget)
    }

    @Test func observationsNeedNoProvenance() {
        #expect(!RelationshipType.observedOn.requiresProvenance)
    }

    @Test func observationsCarryNoDefaultConfidence() {
        #expect(RelationshipType.observedOn.defaultConfidence == nil)
    }
}
