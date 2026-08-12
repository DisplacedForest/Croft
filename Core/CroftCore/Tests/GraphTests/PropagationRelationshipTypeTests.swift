import Graph
import Testing

struct PropagationRelationshipTypeTests {
    @Test func propagationRawValuesAreStableStrings() {
        #expect(RelationshipType.lotOf.rawValue == "LOT_OF")
        #expect(RelationshipType.sownFrom.rawValue == "SOWN_FROM")
        #expect(EntityType.starterBatch.rawValue == "starter_batch")
    }

    @Test(arguments: [RelationshipType.lotOf, .sownFrom])
    func propagationRelationshipsRoundTripThroughRawValue(type: RelationshipType) {
        #expect(RelationshipType(rawValue: type.rawValue) == type)
    }

    @Test func propagationRelationshipsCascadeOnDelete() {
        #expect(RelationshipType.lotOf.deleteRule == .cascade)
        #expect(RelationshipType.sownFrom.deleteRule == .cascade)
    }

    @Test func lineageClaimsNeedNoProvenance() {
        #expect(!RelationshipType.lotOf.requiresProvenance)
        #expect(!RelationshipType.sownFrom.requiresProvenance)
    }

    @Test func lineageClaimsCarryNoDefaultConfidence() {
        #expect(RelationshipType.lotOf.defaultConfidence == nil)
        #expect(RelationshipType.sownFrom.defaultConfidence == nil)
    }
}
