import Graph
import Testing

struct KnowledgeRelationshipTypeTests {
    @Test func knowledgeRawValuesAreStableStrings() {
        #expect(RelationshipType.vectorOf.rawValue == "VECTOR_OF")
        #expect(RelationshipType.resistantTo.rawValue == "RESISTANT_TO")
    }

    @Test(arguments: [RelationshipType.vectorOf, .resistantTo])
    func knowledgeRelationshipsRoundTripThroughRawValue(type: RelationshipType) {
        #expect(RelationshipType(rawValue: type.rawValue) == type)
    }

    @Test func knowledgeRelationshipsCascadeOnDelete() {
        #expect(RelationshipType.vectorOf.deleteRule == .cascade)
        #expect(RelationshipType.resistantTo.deleteRule == .cascade)
    }

    @Test func knowledgeClaimsFollowTheDiseasePrecedentOnProvenance() {
        #expect(!RelationshipType.vectorOf.requiresProvenance)
        #expect(!RelationshipType.resistantTo.requiresProvenance)
    }

    @Test func knowledgeClaimsCarryNoDefaultConfidence() {
        #expect(RelationshipType.vectorOf.defaultConfidence == nil)
        #expect(RelationshipType.resistantTo.defaultConfidence == nil)
    }
}
