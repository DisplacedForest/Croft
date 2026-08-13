import Domain
import Foundation
import GRDB
import Graph
import Persistence
import Testing

@testable import Knowledge

struct SnapshotTests {
    @Test func aSnapshotOpensReadOnlyWithMetaAndAttribution() throws {
        let fixture = try KnowledgeFixture()
        try fixture.build()
        let snapshot = try KnowledgeSnapshot.open(at: fixture.output)
        let meta = try snapshot.meta()
        #expect(meta["importer_version"] == KnowledgeImporter.importerVersion)
        #expect(meta["schema_migration_head"] == SchemaMigrations.identifiers.last)
        #expect(
            meta["snapshot_version"]
                == "crop-profiles@0.1.0+cultivar-catalog@0.1.0"
                + "+garden-pest-disease-cultivar-seed@0.3.0#importer1")
        #expect(meta["input_sha256:crop-profiles.json"]?.count == 64)
        #expect(meta["input_provenance:crop-profiles"] == "fixture crops")
        #expect(
            try snapshot.attributions(for: "species:solanum-lycopersicum")
                == ["https://example.org/tomato"])
    }

    @Test func aSnapshotRejectsWrites() throws {
        let fixture = try KnowledgeFixture()
        try fixture.build()
        let snapshot = try KnowledgeSnapshot.open(at: fixture.output)
        #expect(throws: DatabaseError.self) {
            try snapshot.database.writer.write { db in
                try db.execute(sql: "DELETE FROM species")
            }
        }
    }

    @Test func aForeignDatabaseIsRefused() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("foreign-\(UUID().uuidString).sqlite")
        let queue = try DatabaseQueue(path: url.path)
        try queue.write { db in
            try db.execute(sql: "CREATE TABLE stray (id INTEGER PRIMARY KEY)")
        }
        #expect(throws: DatabaseIdentityError.self) {
            try KnowledgeSnapshot.open(at: url)
        }
    }

    @Test func aUserDatabaseWithoutKnowledgeTablesIsRefused() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("plain-\(UUID().uuidString).sqlite")
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        let queue = try DatabaseQueue(path: url.path, configuration: configuration)
        _ = try AppDatabase(queue)
        #expect(throws: KnowledgeSnapshot.SnapshotError.missingMetaTable(url.path)) {
            try KnowledgeSnapshot.open(at: url)
        }
    }

    @Test func plantPageQueryShapesAnswerOffline() throws {
        let fixture = try KnowledgeFixture()
        try fixture.build()
        let database = try AppDatabase.openReadOnly(at: fixture.output)
        let species = SpeciesRepository(database)
        let cultivars = CultivarRepository(database)
        let tomatoID = Species.ID(rawValue: "species:solanum-lycopersicum")
        let tomato = try #require(try species.fetch(id: tomatoID))
        #expect(tomato.scientificName == "Solanum lycopersicum")
        #expect(try cultivars.cultivars(ofSpecies: tomatoID).count == 3)
        let threats = try database.writer.read { db -> (pests: [String], diseases: [String]) in
            (
                pests: try GraphStore.outgoing(
                    from: tomatoID.rawValue, via: .hostOf, in: db
                ).map(\.target.id),
                diseases: try GraphStore.outgoing(
                    from: tomatoID.rawValue, via: .susceptibleTo, in: db
                ).map(\.target.id)
            )
        }
        #expect(threats.pests == ["pest:green-peach-aphid", "pest:tomato-hornworm"])
        #expect(
            threats.diseases == [
                "disease:clubroot", "disease:early-blight", "disease:mosaic-virus",
            ])
    }

    @Test func attributionMarkdownListsSourcesAndCitations() throws {
        let fixture = try KnowledgeFixture()
        try fixture.build()
        let markdown = try AttributionWriter.markdown(for: fixture.output)
        #expect(markdown.contains("# Knowledge snapshot attribution"))
        #expect(markdown.contains("- **crop-profiles**: fixture crops"))
        #expect(markdown.contains("### species:solanum-lycopersicum"))
        #expect(markdown.contains("- https://example.org/tomato"))
    }
}
