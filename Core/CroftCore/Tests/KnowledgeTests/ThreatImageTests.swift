import Foundation
import GRDB
import Persistence
import Testing

@testable import Knowledge

struct ThreatImageTests {
    private func fixture(_ entries: [String]) throws -> KnowledgeFixture {
        try KnowledgeFixture.threatFixture(entries)
    }

    private func rows(_ fixture: KnowledgeFixture) throws -> [Row] {
        try AppDatabase.openReadOnly(at: fixture.output).writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM knowledge_image
                    WHERE owner_kind IN ('pest', 'disease')
                    ORDER BY owner_kind, owner_id, kind, file
                    """
            )
        }
    }

    @Test func threatImagesResolveOwnersAndHostPairs() throws {
        let fixture = try fixture(KnowledgeFixture.threatEntries)
        let summary = try fixture.build()
        #expect(summary.counts["images"] == 6)
        let found = try rows(fixture)
        #expect(found.count == 4)
        let keyed = Dictionary(
            uniqueKeysWithValues: found.map { ($0["file"] as String, $0) })
        let organism = try #require(keyed["hornworm.jpg"])
        #expect(organism["owner_id"] == "pest:tomato-hornworm")
        #expect(organism["kind"] == "organism")
        #expect(organism["related_id"] == DatabaseValue.null)
        let damage = try #require(keyed["hornworm-damage.jpg"])
        #expect(damage["owner_id"] == "pest:tomato-hornworm")
        #expect(damage["related_id"] == "species:solanum-lycopersicum")
        let symptom = try #require(keyed["early-blight-tomato.jpg"])
        #expect(symptom["owner_kind"] == "disease")
        #expect(symptom["owner_id"] == "disease:early-blight")
        #expect(symptom["related_id"] == "species:solanum-lycopersicum")
    }

    @Test func doubledRunsWithThreatImagesStayIdentical() throws {
        let fixture = try fixture(KnowledgeFixture.threatEntries)
        try fixture.build()
        let first = try KnowledgeSnapshot.logicalDump(at: fixture.output)
        try fixture.build()
        #expect(try first == KnowledgeSnapshot.logicalDump(at: fixture.output))
        #expect(first.contains("early-blight-tomato.jpg"))
    }

    @Test func anUnknownPestSlugFailsTheImport() throws {
        let fixture = try fixture([
            KnowledgeFixture.threatEntry(
                slug: "pest/moon-weevil", ownerKind: "pest", kind: "organism",
                file: "hornworm.jpg")
        ])
        #expect(
            throws: ImportError.unknownImageOwner(file: "hornworm.jpg", slug: "pest/moon-weevil")
        ) {
            try fixture.build()
        }
    }

    @Test func aBarePestSlugWithoutItsNamespaceFailsTheImport() throws {
        let fixture = try fixture([
            KnowledgeFixture.threatEntry(
                slug: "tomato-hornworm", ownerKind: "pest", kind: "organism",
                file: "hornworm.jpg")
        ])
        #expect(throws: ImportError.self) {
            try fixture.build()
        }
    }

    @Test func anUnresolvableRelatedSlugFailsTheImport() throws {
        let fixture = try fixture([
            KnowledgeFixture.threatEntry(
                slug: "pest/tomato-hornworm", ownerKind: "pest", kind: "damage",
                file: "hornworm-damage.jpg", relatedSlug: "kudzu")
        ])
        #expect(
            throws: ImportError.unknownImageRelation(
                slug: "pest/tomato-hornworm", relatedSlug: "kudzu")
        ) {
            try fixture.build()
        }
    }

    @Test func aRelatedSlugThatIsNotAHostFailsTheImport() throws {
        let fixture = try fixture([
            KnowledgeFixture.threatEntry(
                slug: "disease/early-blight", ownerKind: "disease", kind: "symptom",
                file: "early-blight-tomato.jpg", relatedSlug: "summer-squash")
        ])
        #expect(
            throws: ImportError.unrelatedImageHost(
                slug: "disease/early-blight", relatedSlug: "summer-squash")
        ) {
            try fixture.build()
        }
    }

    @Test func aHostRelationshipFromAFannedOutCropIsAccepted() throws {
        let fixture = try fixture([
            KnowledgeFixture.threatEntry(
                slug: "pest/green-peach-aphid", ownerKind: "pest", kind: "damage",
                file: "hornworm-damage.jpg", relatedSlug: "summer-squash")
        ])
        let summary = try fixture.build()
        #expect(summary.counts["images"] == 3)
    }

    @Test func duplicateImageKeysFailTheImport() throws {
        let entry = KnowledgeFixture.threatEntry(
            slug: "pest/tomato-hornworm", ownerKind: "pest", kind: "organism",
            file: "hornworm.jpg")
        let fixture = try fixture([entry, entry])
        #expect(throws: ImportError.self) {
            try fixture.build()
        }
    }
}
