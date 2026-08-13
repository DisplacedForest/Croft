import Foundation
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

    @Test func theCommittedInputsMatchTheirPins() throws {
        let lock = try InputsLock.load(from: inputsDirectory)
        #expect(lock.pinned.count == 3)
        for (name, _) in lock.pinned.sorted(by: { $0.key < $1.key }) {
            let data = try Data(contentsOf: inputsDirectory.appendingPathComponent(name))
            try lock.verify(fileName: name, data: data)
        }
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
        let importer = KnowledgeImporter(inputDirectory: inputsDirectory)
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

        let dump = try KnowledgeSnapshot.logicalDump(at: first)
        for leak in ["cdn.shopify.com", "edenbrothers.com", "migardener.com", "flavor_profile"] {
            #expect(!dump.contains(leak))
        }

        let size = try FileManager.default.attributesOfItem(atPath: first.path)[.size] as? Int
        #expect((size ?? .max) < 30_000_000)
    }

    @Test func knownFactsSurviveTheRealImport() throws {
        let importer = KnowledgeImporter(inputDirectory: inputsDirectory)
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
