import Graph
import Testing

struct GardenTaskRelationshipTypeTests {
    @Test func taskRawValuesAreStableStrings() {
        #expect(RelationshipType.taskFor.rawValue == "TASK_FOR")
        #expect(EntityType.task.rawValue == "task")
    }

    @Test func taskForRoundTripsThroughRawValue() {
        #expect(RelationshipType(rawValue: "TASK_FOR") == .taskFor)
        #expect(EntityType(rawValue: "task") == .task)
    }

    @Test func taskForRestrictsDeletingItsTarget() {
        #expect(RelationshipType.taskFor.deleteRule == .restrictTarget)
    }

    @Test func tasksNeedNoProvenance() {
        #expect(!RelationshipType.taskFor.requiresProvenance)
    }

    @Test func tasksCarryNoDefaultConfidence() {
        #expect(RelationshipType.taskFor.defaultConfidence == nil)
    }
}
