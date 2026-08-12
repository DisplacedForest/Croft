import Foundation
import GRDB
import Graph
import Persistence
import Testing

private struct FixturePlant: Codable, Equatable, FetchableRecord, PersistableRecord, GraphEntity {
    static let databaseTableName = "fixture_plant"
    static var entityType: EntityType { .plant }

    var id: String
    var name: String

    var entityID: String { id }
}

private func makeDatabase() throws -> AppDatabase {
    try AppDatabase.inMemory()
}

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

struct EntityRegistryTests {
    @Test func registerAssignsStableIdentityAndType() throws {
        let database = try makeDatabase()
        let ref = EntityRef(id: "plant-1", type: .plant)
        try database.writer.write { db in
            try GraphStore.register(ref, in: db)
        }
        let found = try database.writer.read { db in
            try GraphStore.registered("plant-1", in: db)
        }
        #expect(found == ref)
    }

    @Test func registerIsIdempotent() throws {
        let database = try makeDatabase()
        let ref = EntityRef(id: "plant-1", type: .plant)
        try database.writer.write { db in
            try GraphStore.register(ref, in: db)
            try GraphStore.register(ref, in: db)
        }
        let count = try database.writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM entity")
        }
        #expect(count == 1)
    }

    @Test func lookupOfUnregisteredEntityReturnsNil() throws {
        let database = try makeDatabase()
        let found = try database.writer.read { db in
            try GraphStore.registered("missing", in: db)
        }
        #expect(found == nil)
    }

    @Test func unknownEntityTypeIsRejectedByTheDatabase() throws {
        let database = try makeDatabase()
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try db.execute(
                    sql: "INSERT INTO entity (id, entity_type) VALUES ('x', 'starship')")
            }
        }
    }
}

struct EdgeIntegrityTests {
    @Test func danglingEdgeIsRejectedByTheDatabase() throws {
        let database = try makeDatabase()
        try database.writer.write { db in
            try GraphStore.register(EntityRef(id: "plant-1", type: .plant), in: db)
        }
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id)
                        VALUES ('e1', 'plant-1', 'SUSCEPTIBLE_TO', 'missing')
                        """
                )
            }
        }
    }

    @Test func unknownRelationshipTypeIsRejectedByTheDatabase() throws {
        let database = try makeDatabase()
        try database.writer.write { db in
            try GraphStore.register(EntityRef(id: "a", type: .plant), in: db)
            try GraphStore.register(EntityRef(id: "b", type: .plant), in: db)
        }
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id)
                        VALUES ('e1', 'a', 'BEST_FRIEND_OF', 'b')
                        """
                )
            }
        }
    }

    @Test func duplicateEdgeIsRejected() throws {
        let database = try makeDatabase()
        let plant = EntityRef(id: "plant-1", type: .plant)
        let disease = EntityRef(id: "disease-1", type: .disease)
        try database.writer.write { db in
            try GraphStore.register(plant, in: db)
            try GraphStore.register(disease, in: db)
            try GraphStore.relate(from: plant, .susceptibleTo, to: disease, in: db)
        }
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try GraphStore.relate(from: plant, .susceptibleTo, to: disease, in: db)
            }
        }
    }

    @Test func confidenceOutsideUnitRangeIsRejected() throws {
        let database = try makeDatabase()
        let plant = EntityRef(id: "plant-1", type: .plant)
        let disease = EntityRef(id: "disease-1", type: .disease)
        try database.writer.write { db in
            try GraphStore.register(plant, in: db)
            try GraphStore.register(disease, in: db)
        }
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try GraphStore.relate(
                    from: plant, .susceptibleTo, to: disease,
                    provenance: Provenance(confidence: 1.5), in: db
                )
            }
        }
    }
}

struct DeleteSemanticsTests {
    @Test(arguments: RelationshipType.allCases)
    func deletingTheTargetFollowsTheDeclaredRule(type: RelationshipType) throws {
        let database = try makeDatabase()
        let source = EntityRef(id: "source", type: .plant)
        let target = EntityRef(id: "target", type: .gardenLocation)
        try database.writer.write { db in
            try GraphStore.register(source, in: db)
            try GraphStore.register(target, in: db)
            try GraphStore.relate(from: source, type, to: target, in: db)
        }
        switch type.deleteRule {
        case .cascade:
            try database.writer.write { db in
                try GraphStore.deleteEntity(target.id, in: db)
            }
            let edges = try database.writer.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM relationship")
            }
            #expect(edges == 0)
        case .restrictTarget:
            #expect(throws: DatabaseError.self) {
                try database.writer.write { db in
                    try GraphStore.deleteEntity(target.id, in: db)
                }
            }
            let kept = try database.writer.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM relationship")
            }
            #expect(kept == 1)
        }
    }

    @Test(arguments: RelationshipType.allCases)
    func deletingTheSourceAlwaysCascadesItsEdges(type: RelationshipType) throws {
        let database = try makeDatabase()
        let source = EntityRef(id: "source", type: .planting)
        let target = EntityRef(id: "target", type: .gardenLocation)
        try database.writer.write { db in
            try GraphStore.register(source, in: db)
            try GraphStore.register(target, in: db)
            try GraphStore.relate(from: source, type, to: target, in: db)
            try GraphStore.deleteEntity(source.id, in: db)
        }
        let edges = try database.writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM relationship")
        }
        #expect(edges == 0)
    }

    @Test func restrictedTargetBecomesDeletableOnceEdgesAreRemoved() throws {
        let database = try makeDatabase()
        let planting = EntityRef(id: "planting-1", type: .planting)
        let bed = EntityRef(id: "bed-1", type: .gardenLocation)
        let edge = try database.writer.write { db in
            try GraphStore.register(planting, in: db)
            try GraphStore.register(bed, in: db)
            return try GraphStore.relate(from: planting, .locatedIn, to: bed, in: db)
        }
        try database.writer.write { db in
            try GraphStore.unrelate(edgeID: edge.id, in: db)
            try GraphStore.deleteEntity(bed.id, in: db)
        }
        let remaining = try database.writer.read { db in
            try GraphStore.registered(bed.id, in: db)
        }
        #expect(remaining == nil)
    }
}

struct QueryAPITests {
    private struct FixtureGraph {
        let database: AppDatabase
        let tomato: EntityRef
        let basil: EntityRef
        let blight: EntityRef
    }

    private func makeFixtureGraph() throws -> FixtureGraph {
        let database = try makeDatabase()
        let tomato = EntityRef(id: "tomato", type: .plant)
        let basil = EntityRef(id: "basil", type: .plant)
        let blight = EntityRef(id: "blight", type: .disease)
        try database.writer.write { db in
            try GraphStore.register(tomato, in: db)
            try GraphStore.register(basil, in: db)
            try GraphStore.register(blight, in: db)
            try GraphStore.relate(from: tomato, .susceptibleTo, to: blight, in: db)
            try GraphStore.relate(from: tomato, .companionWith, to: basil, in: db)
            try GraphStore.relate(from: basil, .companionWith, to: tomato, in: db)
        }
        return FixtureGraph(database: database, tomato: tomato, basil: basil, blight: blight)
    }

    @Test func outgoingEdgesAreFilteredByType() throws {
        let fixture = try makeFixtureGraph()
        let susceptible = try fixture.database.writer.read { db in
            try GraphStore.outgoing(from: fixture.tomato.id, via: .susceptibleTo, in: db)
        }
        let companions = try fixture.database.writer.read { db in
            try GraphStore.outgoing(from: fixture.tomato.id, via: .companionWith, in: db)
        }
        #expect(susceptible.map(\.target) == [fixture.blight])
        #expect(companions.map(\.target) == [fixture.basil])
        #expect(
            susceptible.allSatisfy { $0.source == fixture.tomato && $0.type == .susceptibleTo })
    }

    @Test func incomingEdgesAreFilteredByType() throws {
        let fixture = try makeFixtureGraph()
        let incoming = try fixture.database.writer.read { db in
            try GraphStore.incoming(to: fixture.tomato.id, via: .companionWith, in: db)
        }
        #expect(incoming.map(\.source) == [fixture.basil])
        let none = try fixture.database.writer.read { db in
            try GraphStore.incoming(to: fixture.tomato.id, via: .susceptibleTo, in: db)
        }
        #expect(none.isEmpty)
    }

    @Test func provenanceRoundTripsThroughTheEdge() throws {
        let database = try makeDatabase()
        let plant = EntityRef(id: "plant-1", type: .plant)
        let pest = EntityRef(id: "pest-1", type: .pest)
        let provenance = Provenance(
            source: "RHS pest guide",
            sourceType: .reference,
            confidence: 0.8,
            notes: "common on outdoor crops"
        )
        try database.writer.write { db in
            try GraphStore.register(plant, in: db)
            try GraphStore.register(pest, in: db)
            try GraphStore.relate(
                from: pest, .hostOf, to: plant, provenance: provenance, in: db)
        }
        let edges = try database.writer.read { db in
            try GraphStore.outgoing(from: pest.id, via: .hostOf, in: db)
        }
        #expect(edges.count == 1)
        #expect(edges.first?.provenance == provenance)
    }

    @Test func endpointsResolveToDomainModels() throws {
        let database = try makeDatabase()
        let tomato = FixturePlant(id: "tomato", name: "Tomato")
        let basil = FixturePlant(id: "basil", name: "Basil")
        try database.writer.write { db in
            try db.execute(
                sql: """
                    CREATE TABLE fixture_plant (
                        id TEXT PRIMARY KEY NOT NULL,
                        name TEXT NOT NULL
                    )
                    """
            )
            try tomato.insert(db)
            try basil.insert(db)
            try GraphStore.register(tomato.entityRef, in: db)
            try GraphStore.register(basil.entityRef, in: db)
            try GraphStore.relate(
                from: tomato.entityRef, .companionWith, to: basil.entityRef, in: db)
        }
        let resolved = try database.writer.read { db in
            let edges = try GraphStore.outgoing(from: tomato.id, via: .companionWith, in: db)
            return try GraphStore.resolve(edges.map(\.target), as: FixturePlant.self, in: db)
        }
        #expect(resolved == [basil])
    }

    @Test func resolveIgnoresRefsOfOtherTypes() throws {
        let database = try makeDatabase()
        try database.writer.write { db in
            try db.execute(
                sql: """
                    CREATE TABLE fixture_plant (
                        id TEXT PRIMARY KEY NOT NULL,
                        name TEXT NOT NULL
                    )
                    """
            )
        }
        let refs = [EntityRef(id: "blight", type: .disease)]
        let resolved = try database.writer.read { db in
            try GraphStore.resolve(refs, as: FixturePlant.self, in: db)
        }
        #expect(resolved.isEmpty)
    }
}
