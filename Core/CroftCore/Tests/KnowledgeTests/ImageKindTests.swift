import Foundation
import Testing

@testable import Knowledge

struct KindOwnerCase: Sendable {
    let kind: String
    let ownerKind: String
    let slug: String

    static let mismatches: [KindOwnerCase] = [
        KindOwnerCase(kind: "catalog", ownerKind: "pest", slug: "pest/tomato-hornworm"),
        KindOwnerCase(kind: "catalog", ownerKind: "disease", slug: "disease/early-blight"),
        KindOwnerCase(kind: "organism", ownerKind: "species", slug: "tomato"),
        KindOwnerCase(kind: "organism", ownerKind: "cultivar", slug: "tomato/brandywine"),
        KindOwnerCase(kind: "symptom", ownerKind: "pest", slug: "pest/tomato-hornworm"),
        KindOwnerCase(kind: "symptom", ownerKind: "species", slug: "tomato"),
        KindOwnerCase(kind: "damage", ownerKind: "disease", slug: "disease/early-blight"),
        KindOwnerCase(kind: "frass", ownerKind: "disease", slug: "disease/early-blight"),
        KindOwnerCase(kind: "egg_mass", ownerKind: "species", slug: "tomato"),
        KindOwnerCase(kind: "lifecycle_stage", ownerKind: "disease", slug: "disease/early-blight"),
    ]
}

struct ImageKindTests {
    private func entry(
        kind: String,
        ownerKind: String = "pest",
        slug: String = "pest/tomato-hornworm",
        relatedSlug: String? = nil
    ) -> String {
        KnowledgeFixture.threatEntry(
            slug: slug, ownerKind: ownerKind, kind: kind, file: "hornworm.jpg",
            relatedSlug: relatedSlug)
    }

    @Test(arguments: ["portrait", "CATALOG", "", "close_up", "egg-mass"])
    func anUnknownKindFailsTheImport(kind: String) throws {
        let fixture = try KnowledgeFixture.threatFixture([entry(kind: kind)])
        #expect(
            throws: ImportError.disallowedImageKind(slug: "pest/tomato-hornworm", kind: kind)
        ) {
            try fixture.build()
        }
    }

    @Test(arguments: KindOwnerCase.mismatches)
    func aKindOnTheWrongOwnerFailsTheImport(mismatch: KindOwnerCase) throws {
        let related = ImageKind(rawValue: mismatch.kind)?.relatedRule == .required
        let fixture = try KnowledgeFixture.threatFixture([
            entry(
                kind: mismatch.kind, ownerKind: mismatch.ownerKind, slug: mismatch.slug,
                relatedSlug: related ? "tomato" : nil)
        ])
        #expect(
            throws: ImportError.imageKindOwnerMismatch(
                slug: mismatch.slug, kind: mismatch.kind, ownerKind: mismatch.ownerKind)
        ) {
            try fixture.build()
        }
    }

    @Test(arguments: [
        ("catalog", "species", "tomato"),
        ("organism", "pest", "pest/tomato-hornworm"),
    ])
    func aRelatedSlugOnAKindThatForbidsItFailsTheImport(
        kind: String, ownerKind: String, slug: String
    ) throws {
        let fixture = try KnowledgeFixture.threatFixture([
            entry(kind: kind, ownerKind: ownerKind, slug: slug, relatedSlug: "tomato")
        ])
        #expect(throws: ImportError.unexpectedRelatedSlug(slug: slug, kind: kind)) {
            try fixture.build()
        }
    }

    @Test(arguments: ["symptom", "damage", "frass", "egg_mass"])
    func aMissingRelatedSlugOnAPairKindFailsTheImport(kind: String) throws {
        let ownerKind = kind == "symptom" ? "disease" : "pest"
        let slug = kind == "symptom" ? "disease/early-blight" : "pest/tomato-hornworm"
        let fixture = try KnowledgeFixture.threatFixture([
            entry(kind: kind, ownerKind: ownerKind, slug: slug)
        ])
        #expect(throws: ImportError.missingRelatedSlug(slug: slug, kind: kind)) {
            try fixture.build()
        }
    }

    @Test func aLifecycleStageImageMayOmitItsRelatedSlug() throws {
        let fixture = try KnowledgeFixture.threatFixture([entry(kind: "lifecycle_stage")])
        let summary = try fixture.build()
        #expect(summary.counts["images"] == 3)
    }

    @Test func aLifecycleStageImageMayCarryItsRelatedSlug() throws {
        let fixture = try KnowledgeFixture.threatFixture([
            entry(kind: "lifecycle_stage", relatedSlug: "tomato")
        ])
        let summary = try fixture.build()
        #expect(summary.counts["images"] == 3)
    }

    @Test func theKindVocabularyIsExactlyTheAgreedSet() throws {
        #expect(
            Set(ImageKind.allCases.map(\.rawValue)) == [
                "catalog", "organism", "symptom", "damage", "frass", "egg_mass",
                "lifecycle_stage",
            ])
    }
}
