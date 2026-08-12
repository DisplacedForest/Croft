import Domain
import GRDB
import Graph
import Testing

@testable import Persistence

private struct Fixture {
    let database: AppDatabase
    let repository: GardenStructureRepository
    let home: Property
    let backGarden: Garden

    init() throws {
        database = try AppDatabase.inMemory()
        repository = GardenStructureRepository(database)
        home = Property(name: "Home")
        backGarden = Garden(name: "Back Garden")
        try repository.create(home)
        try repository.create(backGarden, in: home.id)
    }
}

struct GardenStructureHierarchyTests {
    @Test func theFullHierarchyIsExpressible() throws {
        let fixture = try Fixture()
        let vegetablePatch = GrowingArea(name: "Vegetable Patch")
        try fixture.repository.create(vegetablePatch, in: fixture.backGarden.id)
        let raisedOne = Bed(name: "Raised Bed 1", kind: .raised)
        let raisedTwo = Bed(name: "Raised Bed 2", kind: .raised)
        try fixture.repository.create(raisedOne, in: .growingArea(vegetablePatch.id))
        try fixture.repository.create(raisedTwo, in: .growingArea(vegetablePatch.id))
        let herbBed = Bed(name: "Herb Bed", kind: .container)
        try fixture.repository.create(herbBed, in: .garden(fixture.backGarden.id))

        #expect(try fixture.repository.properties() == [fixture.home])
        #expect(try fixture.repository.gardens(in: fixture.home.id) == [fixture.backGarden])
        #expect(
            try fixture.repository.growingAreas(in: fixture.backGarden.id) == [vegetablePatch])
        #expect(
            try fixture.repository.beds(in: .growingArea(vegetablePatch.id))
                == [raisedOne, raisedTwo])
        #expect(try fixture.repository.beds(in: .garden(fixture.backGarden.id)) == [herbBed])
    }

    @Test func aMissingParentIsRejected() throws {
        let fixture = try Fixture()
        let orphan = Garden(name: "Orphan")
        #expect(throws: GardenStructureError.parentNotFound("missing")) {
            try fixture.repository.create(orphan, in: Property.ID(rawValue: "missing"))
        }
    }

    @Test func aWrongLevelParentIsRejected() throws {
        let fixture = try Fixture()
        let bed = Bed(name: "Bed", kind: .raised)
        try fixture.repository.create(bed, in: .garden(fixture.backGarden.id))
        let impostor = Property.ID(rawValue: bed.id.rawValue)
        let garden = Garden(name: "Nested Garden")
        #expect(throws: GardenStructureError.parentNotFound(bed.id.rawValue)) {
            try fixture.repository.create(garden, in: impostor)
        }
    }

    @Test func aSecondParentIsRejectedByTheDatabase() throws {
        let fixture = try Fixture()
        let second = Property(name: "Allotment")
        try fixture.repository.create(second)
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try GraphStore.relate(
                    from: EntityRef(id: fixture.backGarden.id.rawValue, type: .garden),
                    .locatedIn,
                    to: EntityRef(id: second.id.rawValue, type: .property),
                    in: db
                )
            }
        }
    }

    @Test func anUnknownBedKindIsRejectedByTheDatabase() throws {
        let fixture = try Fixture()
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO bed (id, name, kind, archived)
                        VALUES ('b1', 'Weird Bed', 'hydroponic', 0)
                        """
                )
            }
        }
    }
}

struct GardenStructureMutationTests {
    @Test func renamePreservesChildrenAndEdges() throws {
        let fixture = try Fixture()
        let bed = Bed(name: "Bed", kind: .inGround)
        try fixture.repository.create(bed, in: .garden(fixture.backGarden.id))
        try fixture.repository.renameGarden(fixture.backGarden.id, to: "Kitchen Garden")
        let renamed = try fixture.repository.gardens(in: fixture.home.id)
        #expect(renamed.map(\.name) == ["Kitchen Garden"])
        #expect(renamed.map(\.id) == [fixture.backGarden.id])
        #expect(try fixture.repository.beds(in: .garden(fixture.backGarden.id)) == [bed])
    }

    @Test func movePreservesChildrenAndTheirEdges() throws {
        let fixture = try Fixture()
        let patch = GrowingArea(name: "Patch")
        try fixture.repository.create(patch, in: fixture.backGarden.id)
        let bed = Bed(name: "Bed", kind: .raised)
        try fixture.repository.create(bed, in: .growingArea(patch.id))
        let frontGarden = Garden(name: "Front Garden")
        try fixture.repository.create(frontGarden, in: fixture.home.id)

        try fixture.repository.moveGrowingArea(patch.id, to: frontGarden.id)

        #expect(try fixture.repository.growingAreas(in: fixture.backGarden.id).isEmpty)
        #expect(try fixture.repository.growingAreas(in: frontGarden.id) == [patch])
        #expect(try fixture.repository.beds(in: .growingArea(patch.id)) == [bed])
    }

    @Test func moveToAMissingParentThrowsAndChangesNothing() throws {
        let fixture = try Fixture()
        #expect(throws: GardenStructureError.parentNotFound("missing")) {
            try fixture.repository.moveGarden(
                fixture.backGarden.id, to: Property.ID(rawValue: "missing"))
        }
        #expect(try fixture.repository.gardens(in: fixture.home.id) == [fixture.backGarden])
    }

    @Test func deletingAContainerWithChildrenIsBlocked() throws {
        let fixture = try Fixture()
        #expect(throws: DatabaseError.self) {
            try fixture.repository.deleteProperty(fixture.home.id)
        }
        #expect(try fixture.repository.properties() == [fixture.home])
        #expect(try fixture.repository.gardens(in: fixture.home.id) == [fixture.backGarden])
    }

    @Test func deletingALeafRemovesTheRowAndItsEdges() throws {
        let fixture = try Fixture()
        try fixture.repository.deleteGarden(fixture.backGarden.id)
        #expect(try fixture.repository.gardens(in: fixture.home.id).isEmpty)
        let remaining = try fixture.database.writer.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM relationship WHERE from_entity_id = ?",
                arguments: [fixture.backGarden.id.rawValue]
            )
        }
        #expect(remaining == 0)
        try fixture.repository.deleteProperty(fixture.home.id)
        #expect(try fixture.repository.properties().isEmpty)
    }

    @Test func archivingAContainerWithChildrenSucceedsAndPreservesThem() throws {
        let fixture = try Fixture()
        try fixture.repository.setPropertyArchived(fixture.home.id, true)
        #expect(try fixture.repository.properties().isEmpty)
        let archived = try fixture.repository.properties(includeArchived: true)
        #expect(archived.map(\.id) == [fixture.home.id])
        #expect(archived.map(\.isArchived) == [true])
        #expect(try fixture.repository.gardens(in: fixture.home.id) == [fixture.backGarden])
        try fixture.repository.setPropertyArchived(fixture.home.id, false)
        #expect(try fixture.repository.properties() == [fixture.home])
    }

    @Test func archivedChildrenAreHiddenFromListingsUnlessRequested() throws {
        let fixture = try Fixture()
        let patch = GrowingArea(name: "Patch")
        try fixture.repository.create(patch, in: fixture.backGarden.id)
        let bed = Bed(name: "Bed", kind: .raised)
        try fixture.repository.create(bed, in: .growingArea(patch.id))

        try fixture.repository.setGardenArchived(fixture.backGarden.id, true)
        try fixture.repository.setGrowingAreaArchived(patch.id, true)
        try fixture.repository.setBedArchived(bed.id, true)

        #expect(try fixture.repository.gardens(in: fixture.home.id).isEmpty)
        #expect(try fixture.repository.growingAreas(in: fixture.backGarden.id).isEmpty)
        #expect(try fixture.repository.beds(in: .growingArea(patch.id)).isEmpty)

        #expect(
            try fixture.repository.gardens(in: fixture.home.id, includeArchived: true)
                .map(\.id) == [fixture.backGarden.id])
        #expect(
            try fixture.repository.growingAreas(
                in: fixture.backGarden.id, includeArchived: true
            ).map(\.id) == [patch.id])
        #expect(
            try fixture.repository.beds(in: .growingArea(patch.id), includeArchived: true)
                .map(\.id) == [bed.id])
    }

    @Test func renamingAMissingStructureThrows() throws {
        let fixture = try Fixture()
        #expect(throws: GardenStructureError.structureNotFound("missing")) {
            try fixture.repository.renameBed(Bed.ID(rawValue: "missing"), to: "New Name")
        }
    }
}

struct GardenStructureMigrationTests {
    @Test func graphDataSurvivesTheEntityTableRebuild() throws {
        let queue = try MigrationHarness.database(through: "v003-taxonomy")
        try queue.write { db in
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('p1', 'plant')")
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('d1', 'disease')")
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id, confidence)
                    VALUES ('e1', 'p1', 'SUSCEPTIBLE_TO', 'd1', 0.7)
                    """
            )
        }
        try MigrationHarness.migrateToHead(queue)
        let edge = try queue.read {
            try Row.fetchOne($0, sql: "SELECT * FROM relationship WHERE id = 'e1'")
        }
        #expect(edge?["from_entity_id"] == "p1")
        #expect(edge?["confidence"] == 0.7)
        let types = try queue.read {
            try String.fetchAll(
                $0, sql: "SELECT entity_type FROM entity ORDER BY entity_type")
        }
        #expect(types == ["disease", "plant"])
    }

    @Test func theRestrictTriggerSurvivesTheEntityTableRebuild() throws {
        let queue = try MigrationHarness.database(through: "v003-taxonomy")
        try queue.write { db in
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('b1', 'plant')")
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('g1', 'plant')")
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e1', 'b1', 'LOCATED_IN', 'g1')
                    """
            )
        }
        try MigrationHarness.migrateToHead(queue)
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(sql: "DELETE FROM entity WHERE id = 'g1'")
            }
        }
    }

    @Test func aDanglingEdgeIsStillRejectedAfterTheRebuild() throws {
        let database = try AppDatabase.inMemory()
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id)
                        VALUES ('e1', 'missing', 'LOCATED_IN', 'also-missing')
                        """
                )
            }
        }
    }

    @Test func aTamperedPlaceholderRowBlocksTheRebuildAtomically() throws {
        let queue = try MigrationHarness.database(through: "v003-taxonomy")
        try queue.write { db in
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('x', 'garden_location')")
        }
        #expect(throws: DatabaseError.self) {
            try MigrationHarness.migrateToHead(queue)
        }
        let kept = try queue.read {
            try String.fetchOne($0, sql: "SELECT entity_type FROM entity WHERE id = 'x'")
        }
        #expect(kept == "garden_location")
        let applied = try queue.read {
            try SchemaMigrations.migrator().appliedIdentifiers($0)
        }
        #expect(applied == Set(["v001-baseline", "v002-graph", "v003-taxonomy"]))
    }

    @Test func theRetiredPlaceholderEntityTypeIsRejectedAfterTheRebuild() throws {
        let database = try AppDatabase.inMemory()
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO entity (id, entity_type)
                        VALUES ('x', 'garden_location')
                        """
                )
            }
        }
    }
}
