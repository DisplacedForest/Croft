import Graph
import Testing

struct RelationshipTypeTests {
    @Test func rawValuesAreStableStrings() {
        #expect(RelationshipType.susceptibleTo.rawValue == "SUSCEPTIBLE_TO")
        #expect(RelationshipType.hostOf.rawValue == "HOST_OF")
        #expect(RelationshipType.companionWith.rawValue == "COMPANION_WITH")
        #expect(RelationshipType.locatedIn.rawValue == "LOCATED_IN")
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
    }
}

struct EntityTypeTests {
    @Test func rawValuesAreStableStrings() {
        #expect(EntityType.plant.rawValue == "plant")
        #expect(EntityType.pest.rawValue == "pest")
        #expect(EntityType.disease.rawValue == "disease")
        #expect(EntityType.gardenLocation.rawValue == "garden_location")
        #expect(EntityType.seedLot.rawValue == "seed_lot")
        #expect(EntityType.planting.rawValue == "planting")
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
