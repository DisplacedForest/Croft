import GRDB
import Graph
import Persistence
import Testing

struct DeterministicEdgeIDTests {
    @Test func aCallerSuppliedEdgeIDIsStored() throws {
        let database = try makeDatabase()
        let edge = try database.writer.write { db -> Edge in
            let plant = EntityRef(id: "p1", type: .plant)
            let disease = EntityRef(id: "d1", type: .disease)
            try GraphStore.register(plant, in: db)
            try GraphStore.register(disease, in: db)
            return try GraphStore.relate(
                from: plant, .susceptibleTo, to: disease,
                edgeID: "edge:p1|SUSCEPTIBLE_TO|d1", in: db)
        }
        #expect(edge.id == "edge:p1|SUSCEPTIBLE_TO|d1")
        let stored = try database.writer.read { db in
            try GraphStore.outgoing(from: "p1", via: .susceptibleTo, in: db).map(\.id)
        }
        #expect(stored == ["edge:p1|SUSCEPTIBLE_TO|d1"])
    }

    @Test func anOmittedEdgeIDStillGetsAUniqueGeneratedOne() throws {
        let database = try makeDatabase()
        let ids = try database.writer.write { db -> [String] in
            let plant = EntityRef(id: "p1", type: .plant)
            let pest = EntityRef(id: "x1", type: .pest)
            let disease = EntityRef(id: "d1", type: .disease)
            for ref in [plant, pest, disease] {
                try GraphStore.register(ref, in: db)
            }
            return [
                try GraphStore.relate(from: plant, .hostOf, to: pest, in: db).id,
                try GraphStore.relate(from: plant, .susceptibleTo, to: disease, in: db).id,
            ]
        }
        #expect(ids[0] != ids[1])
        #expect(!ids[0].isEmpty)
    }

    @Test func aDuplicateEdgeIDIsRejected() throws {
        let database = try makeDatabase()
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                let plant = EntityRef(id: "p1", type: .plant)
                let pest = EntityRef(id: "x1", type: .pest)
                let disease = EntityRef(id: "d1", type: .disease)
                for ref in [plant, pest, disease] {
                    try GraphStore.register(ref, in: db)
                }
                try GraphStore.relate(from: plant, .hostOf, to: pest, edgeID: "e1", in: db)
                try GraphStore.relate(
                    from: plant, .susceptibleTo, to: disease, edgeID: "e1", in: db)
            }
        }
    }
}
