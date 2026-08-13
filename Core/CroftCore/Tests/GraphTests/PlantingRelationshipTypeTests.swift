import Graph
import Testing

struct PlantingRelationshipTypeTests {
    @Test func plantingRawValuesAreStableStrings() {
        #expect(RelationshipType.instanceOf.rawValue == "INSTANCE_OF")
        #expect(RelationshipType.plantedFrom.rawValue == "PLANTED_FROM")
        #expect(EntityType.planting.rawValue == "planting")
    }

    @Test(arguments: [RelationshipType.instanceOf, .plantedFrom])
    func plantingRelationshipsRoundTripThroughRawValue(type: RelationshipType) {
        #expect(RelationshipType(rawValue: type.rawValue) == type)
    }

    @Test func plantingRelationshipsCascadeOnDelete() {
        #expect(RelationshipType.instanceOf.deleteRule == .cascade)
        #expect(RelationshipType.plantedFrom.deleteRule == .cascade)
    }

    @Test func plantingClaimsNeedNoProvenance() {
        #expect(!RelationshipType.instanceOf.requiresProvenance)
        #expect(!RelationshipType.plantedFrom.requiresProvenance)
    }

    @Test func plantingClaimsCarryNoDefaultConfidence() {
        #expect(RelationshipType.instanceOf.defaultConfidence == nil)
        #expect(RelationshipType.plantedFrom.defaultConfidence == nil)
    }
}
