import Graph
import Testing

struct HarvestRelationshipTypeTests {
    @Test func harvestRawValuesAreStableStrings() {
        #expect(RelationshipType.harvestedFrom.rawValue == "HARVESTED_FROM")
        #expect(EntityType.harvest.rawValue == "harvest")
    }

    @Test func harvestedFromRoundTripsThroughRawValue() {
        #expect(RelationshipType(rawValue: "HARVESTED_FROM") == .harvestedFrom)
        #expect(EntityType(rawValue: "harvest") == .harvest)
    }

    @Test func harvestedFromRestrictsDeletingItsTarget() {
        #expect(RelationshipType.harvestedFrom.deleteRule == .restrictTarget)
    }

    @Test func harvestsNeedNoProvenance() {
        #expect(!RelationshipType.harvestedFrom.requiresProvenance)
    }

    @Test func harvestsCarryNoDefaultConfidence() {
        #expect(RelationshipType.harvestedFrom.defaultConfidence == nil)
    }
}
