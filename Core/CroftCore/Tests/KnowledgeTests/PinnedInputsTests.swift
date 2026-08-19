import Foundation
import GRDB
import Persistence
import Testing

@testable import Knowledge

struct PinnedInputsTests {
    private var inputsDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("knowledge/inputs", isDirectory: true)
    }

    private var imagesDirectory: URL {
        inputsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("App/Shared/Resources/PlantImages", isDirectory: true)
    }

    private var importer: KnowledgeImporter {
        KnowledgeImporter(inputDirectory: inputsDirectory, imagesDirectory: imagesDirectory)
    }

    private var manifest: PlantImagesFile {
        get throws {
            let url = inputsDirectory.appendingPathComponent(KnowledgeImporter.plantImagesFile)
            return try JSONDecoder().decode(
                PlantImagesFile.self, from: try Data(contentsOf: url))
        }
    }

    private var manifestImageCount: Int {
        get throws { try manifest.images.count }
    }

    @Test func theCommittedInputsMatchTheirPins() throws {
        let lock = try InputsLock.load(from: inputsDirectory)
        #expect(lock.pinned.count == 5)
        for (name, _) in lock.pinned.sorted(by: { $0.key < $1.key }) {
            let data = try Data(contentsOf: inputsDirectory.appendingPathComponent(name))
            try lock.verify(fileName: name, data: data)
        }
    }

    @Test func theCommittedLockIsWhatPinWouldWrite() throws {
        let committed = try InputsLock.load(from: inputsDirectory)
        let regenerated = try InputsLock.regenerated(in: inputsDirectory)
        #expect(committed == regenerated)
    }

    @Test(arguments: [KnowledgeImporter.catalogFile, KnowledgeImporter.pestDiseaseFile])
    func theCommittedSanitizedInputsCarryNoStrippedFields(name: String) throws {
        let data = try Data(contentsOf: inputsDirectory.appendingPathComponent(name))
        let text = try #require(String(data: data, encoding: .utf8))
        for field in CatalogSanitizer.strippedFields {
            #expect(!text.contains("\"\(field)\""))
        }
    }

    @Test func thePinnedInputsBuildADeterministicSnapshot() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("pinned-\(UUID().uuidString)", isDirectory: true)
        let first = base.appendingPathComponent("one.sqlite")
        let second = base.appendingPathComponent("two.sqlite")
        let summary = try importer.buildSnapshot(at: first)
        _ = try importer.buildSnapshot(at: second)
        #expect(
            try KnowledgeSnapshot.logicalDump(at: first)
                == KnowledgeSnapshot.logicalDump(at: second))
        #expect(summary.counts["species"] == 32)
        #expect(summary.counts["pests"] == 31)
        #expect(summary.counts["diseases"] == 37)
        #expect((summary.counts["cultivars"] ?? 0) > 1000)
        #expect(try summary.counts["images"] == manifestImageCount)

        let dump = try KnowledgeSnapshot.logicalDump(at: first)
        for leak in ["cdn.shopify.com", "edenbrothers.com", "migardener.com", "flavor_profile"] {
            #expect(!dump.contains(leak))
        }

        let size = try FileManager.default.attributesOfItem(atPath: first.path)[.size] as? Int
        #expect((size ?? .max) < 30_000_000)
    }

    @Test func theRealImageRowsMatchTheManifestAndCarryFullAttribution() throws {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("images-\(UUID().uuidString).sqlite")
        _ = try importer.buildSnapshot(at: output)
        let rows = try AppDatabase.openReadOnly(at: output).writer.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM knowledge_image")
        }
        var expected: [String: Int] = [:]
        for image in try manifest.images {
            expected[image.ownerKind.rawValue, default: 0] += 1
        }
        var actual: [String: Int] = [:]
        for row in rows {
            actual[row["owner_kind"] as String, default: 0] += 1
        }
        #expect(actual == expected)
        #expect(expected["species"] == 32)
        #expect(expected["cultivar"] == 11)
        for row in rows {
            for column in ["license", "license_url", "artist", "source_page_url"] {
                let value: String? = row[column]
                #expect(value?.isEmpty == false)
            }
            #expect(KnowledgeImporter.allowedImageLicenses.contains(row["license"] as String))
        }
    }

    @Test func everyThreatCarriesAnOrganismImageOnceTheDataLands() throws {
        guard try manifest.images.contains(where: { $0.ownerKind.isThreat }) else { return }
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("threats-\(UUID().uuidString).sqlite")
        _ = try importer.buildSnapshot(at: output)
        let missing = try AppDatabase.openReadOnly(at: output).writer.read { db in
            try String.fetchAll(
                db,
                sql: """
                    SELECT id FROM pest WHERE id NOT IN (
                        SELECT owner_id FROM knowledge_image WHERE kind = 'organism'
                    )
                    UNION
                    SELECT id FROM disease WHERE id NOT IN (
                        SELECT owner_id FROM knowledge_image WHERE kind = 'organism'
                    )
                    ORDER BY 1
                    """
            )
        }
        let acceptedGaps = [
            "disease:fusarium-yellows-brassica",
            "disease:iris-yellow-spot-virus",
            "disease:spinach-downy-mildew",
            "pest:carrot-rust-fly",
        ]
        #expect(missing == acceptedGaps)
    }

    @Test func knownFactsSurviveTheRealImport() throws {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("facts-\(UUID().uuidString).sqlite")
        _ = try importer.buildSnapshot(at: output)
        let dump = try KnowledgeSnapshot.logicalDump(at: output)
        #expect(
            dump.contains(
                "edge:species:solanum-lycopersicum|SUSCEPTIBLE_TO|disease:early-blight"))
        #expect(
            dump.contains("edge:species:solanum-lycopersicum|HOST_OF|pest:tomato-hornworm"))
        #expect(
            dump.contains(
                "edge:pest:green-peach-aphid|VECTOR_OF|disease:cucumber-mosaic-virus"))
        #expect(dump.contains("cultivar:solanum-lycopersicum/iron-lady"))
    }
}
