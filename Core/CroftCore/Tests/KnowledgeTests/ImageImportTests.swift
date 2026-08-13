import Foundation
import GRDB
import Persistence
import Testing

@testable import Knowledge

private struct ImageRow {
    let ownerKind: String
    let ownerID: String
    let relatedID: String?
    let kind: String
    let file: String
    let sha256: String
    let license: String
    let licenseURL: String?
    let artist: String?
    let sourcePageURL: String
    let sourceFileURL: String

    init(_ row: Row) {
        ownerKind = row["owner_kind"]
        ownerID = row["owner_id"]
        relatedID = row["related_id"]
        kind = row["kind"]
        file = row["file"]
        sha256 = row["sha256"]
        license = row["license"]
        licenseURL = row["license_url"]
        artist = row["artist"]
        sourcePageURL = row["source_page_url"]
        sourceFileURL = row["source_file_url"]
    }
}

struct ImageImportTests {
    private func imagedFixture(
        images: String = KnowledgeFixture.images,
        imageFiles: [String: Data] = KnowledgeFixture.imageFiles
    ) throws -> KnowledgeFixture {
        try KnowledgeFixture(images: images, imageFiles: imageFiles)
    }

    private func imageRows(_ fixture: KnowledgeFixture) throws -> [Row] {
        let database = try AppDatabase.openReadOnly(at: fixture.output)
        return try database.writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM knowledge_image ORDER BY owner_kind, owner_id, kind, file
                    """
            )
        }
    }

    @Test func manifestEntriesResolveToSpeciesAndCultivarOwners() throws {
        let fixture = try imagedFixture()
        let summary = try fixture.build()
        #expect(summary.counts["images"] == 2)
        let rows = try imageRows(fixture)
        #expect(rows.count == 2)
        let cultivar = ImageRow(rows[0])
        #expect(cultivar.ownerKind == "cultivar")
        #expect(cultivar.ownerID == "cultivar:solanum-lycopersicum/brandywine")
        #expect(cultivar.file == "brandywine.jpg")
        #expect(cultivar.license == "CC0")
        #expect(cultivar.licenseURL == nil)
        #expect(cultivar.artist == nil)
        #expect(cultivar.relatedID == nil)
        let species = ImageRow(rows[1])
        #expect(species.ownerKind == "species")
        #expect(species.ownerID == "species:solanum-lycopersicum")
        #expect(species.kind == "catalog")
        #expect(species.sha256 == KnowledgeFixture.imageChecksum)
        #expect(species.artist == "A Photographer")
        #expect(species.sourcePageURL == "https://example.org/wiki/File:Tomato.jpg")
        #expect(species.sourceFileURL == "https://example.org/files/Tomato.jpg")
        #expect(species.licenseURL == "https://creativecommons.org/licenses/by/2.0/")
    }

    @Test func anAbsentManifestImportsWithNoImages() throws {
        let fixture = try KnowledgeFixture()
        let summary = try fixture.build()
        #expect(summary.counts["images"] == 0)
        #expect(try imageRows(fixture).isEmpty)
    }

    @Test func anUnknownImageSlugFailsTheImport() throws {
        let fixture = try imagedFixture(
            images: KnowledgeFixture.images.replacingOccurrences(
                of: "\"slug\": \"tomato\"", with: "\"slug\": \"kudzu\""))
        #expect(throws: ImportError.unknownImageOwner(file: "tomato.jpg", slug: "kudzu")) {
            try fixture.build()
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.output.path))
    }

    @Test func anUnknownCultivarImageSlugFailsTheImport() throws {
        let fixture = try imagedFixture(
            images: KnowledgeFixture.images.replacingOccurrences(
                of: "\"slug\": \"tomato/brandywine\"", with: "\"slug\": \"tomato/moon-cheese\""))
        #expect(
            throws: ImportError.unknownImageOwner(
                file: "brandywine.jpg", slug: "tomato/moon-cheese")
        ) {
            try fixture.build()
        }
    }

    @Test func anImageChecksumMismatchFailsTheImport() throws {
        let wrong = String(repeating: "0", count: 64)
        let fixture = try imagedFixture(
            images: KnowledgeFixture.images.replacingOccurrences(
                of: KnowledgeFixture.imageChecksum, with: wrong))
        #expect {
            try fixture.build()
        } throws: { error in
            guard case .checksumMismatch(let file, let expected, _) = error as? ImportError else {
                return false
            }
            return file == "tomato.jpg" && expected == wrong
        }
    }

    @Test func aMissingImageFileFailsTheImport() throws {
        let fixture = try imagedFixture(imageFiles: ["tomato.jpg": KnowledgeFixture.imageBytes])
        #expect(throws: ImportError.missingImageFile("brandywine.jpg")) {
            try fixture.build()
        }
    }

    @Test func anUnpinnedManifestFailsTheImport() throws {
        let fixture = try KnowledgeFixture(
            images: KnowledgeFixture.images,
            imageFiles: KnowledgeFixture.imageFiles,
            unpinned: [KnowledgeImporter.plantImagesFile]
        )
        #expect(throws: ImportError.unpinnedInput(KnowledgeImporter.plantImagesFile)) {
            try fixture.build()
        }
    }

    @Test func aManifestWithoutAnImagesDirectoryFailsTheImport() throws {
        let fixture = try imagedFixture()
        let importer = KnowledgeImporter(inputDirectory: fixture.directory)
        #expect(
            throws: ImportError.missingImageDirectory(KnowledgeImporter.plantImagesFile)
        ) {
            try importer.buildSnapshot(at: fixture.output)
        }
    }

    @Test func doubledRunsWithImagesProduceIdenticalLogicalContent() throws {
        let fixture = try imagedFixture()
        try fixture.build()
        let first = try KnowledgeSnapshot.logicalDump(at: fixture.output)
        try fixture.build()
        let second = try KnowledgeSnapshot.logicalDump(at: fixture.output)
        #expect(first == second)
        #expect(first.contains("tomato.jpg"))
    }

    @Test func theManifestVersionEntersTheSnapshotMeta() throws {
        let fixture = try imagedFixture()
        try fixture.build()
        let meta = try KnowledgeSnapshot.open(at: fixture.output).meta()
        #expect(meta["input_provenance:plant-images"] == "fixture images")
        #expect(meta["snapshot_version"]?.contains("plant-images@1") == true)
        #expect(meta["input_sha256:\(KnowledgeImporter.plantImagesFile)"] != nil)
    }

    @Test func attributionMarkdownListsTheImages() throws {
        let fixture = try imagedFixture()
        try fixture.build()
        let markdown = try AttributionWriter.markdown(for: fixture.output)
        #expect(markdown.contains("## Images"))
        #expect(
            markdown.contains(
                "- `brandywine.jpg` · [source](https://example.org/wiki/File:Brandywine.jpg) · CC0")
        )
        #expect(
            markdown.contains(
                """
                - `tomato.jpg` · [source](https://example.org/wiki/File:Tomato.jpg) · \
                [CC BY 2.0](https://creativecommons.org/licenses/by/2.0/) · A Photographer
                """))
    }

    @Test func attributionMarkdownOmitsImagesWhenThereAreNone() throws {
        let fixture = try KnowledgeFixture()
        try fixture.build()
        let markdown = try AttributionWriter.markdown(for: fixture.output)
        #expect(!markdown.contains("## Images"))
    }
}
