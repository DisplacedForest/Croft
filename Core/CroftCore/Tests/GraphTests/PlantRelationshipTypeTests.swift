import Graph
import Testing

struct PlantRelationshipTypeTests {
    @Test func plantRelationshipRawValuesAreStableStrings() {
        #expect(RelationshipType.antagonisticTo.rawValue == "ANTAGONISTIC_TO")
        #expect(RelationshipType.rotateAwayFrom.rawValue == "ROTATE_AWAY_FROM")
    }

    @Test(arguments: [RelationshipType.antagonisticTo, .rotateAwayFrom])
    func plantRelationshipsRoundTripThroughRawValue(type: RelationshipType) {
        #expect(RelationshipType(rawValue: type.rawValue) == type)
    }

    @Test func plantRelationshipsCascadeOnDelete() {
        #expect(RelationshipType.antagonisticTo.deleteRule == .cascade)
        #expect(RelationshipType.rotateAwayFrom.deleteRule == .cascade)
    }

    @Test func onlyCuratedClaimsRequireProvenance() {
        #expect(RelationshipType.companionWith.requiresProvenance)
        #expect(RelationshipType.antagonisticTo.requiresProvenance)
        #expect(RelationshipType.rotateAwayFrom.requiresProvenance)
        #expect(!RelationshipType.susceptibleTo.requiresProvenance)
        #expect(!RelationshipType.hostOf.requiresProvenance)
        #expect(!RelationshipType.locatedIn.requiresProvenance)
        #expect(!RelationshipType.parasitizedBy.requiresProvenance)
        #expect(!RelationshipType.predatedBy.requiresProvenance)
    }

    @Test(arguments: RelationshipType.allCases)
    func onlyCompanionshipCarriesADefaultConfidence(type: RelationshipType) {
        #expect(type.defaultConfidence == (type == .companionWith ? 0.3 : nil))
    }
}
