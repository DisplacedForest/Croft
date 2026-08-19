import Foundation
import Testing

import struct Domain.LocalizedPlantName

@testable import Knowledge

struct LocalizedNamesTests {
    private func profiles(_ slugs: [String]) throws -> CropProfilesFile {
        let crops = slugs.map { slug in
            """
            {"crop": "\(slug)", "latin_name": "Genus \(slug)", "family": "Family", "citations": []}
            """
        }
        let json = """
            {"meta": {"name": "crop-profiles", "version": "0"},
             "crops": [\(crops.joined(separator: ","))]}
            """
        return try JSONDecoder().decode(CropProfilesFile.self, from: Data(json.utf8))
    }

    private func namesFile(_ rows: String) throws -> LocalizedNamesFile {
        let json = """
            {"meta": {"name": "british-common-names", "version": "0"}, "names": [\(rows)]}
            """
        return try JSONDecoder().decode(LocalizedNamesFile.self, from: Data(json.utf8))
    }

    private let validRow = """
        {"crop": "eggplant", "locale": "en-GB", "name": "aubergine",
         "citations": ["https://example.org"]}
        """

    @Test func aValidFileDecodesAndValidates() throws {
        let file = try namesFile(validRow)
        try KnowledgeImporter.validate(
            localizedNames: file, against: try profiles(["eggplant"]))
        #expect(file.names.first?.name == "aubergine")
        #expect(file.names.first?.locale == "en-GB")
    }

    @Test func anUnknownCropSlugFailsValidation() throws {
        let file = try namesFile(validRow)
        #expect(throws: ImportError.invalidLocalizedName(detail: "unknown crop slug eggplant")) {
            try KnowledgeImporter.validate(
                localizedNames: file, against: try profiles(["tomato"]))
        }
    }

    @Test func aMalformedLocaleTagFailsValidation() throws {
        let file = try namesFile(
            """
            {"crop": "eggplant", "locale": "english", "name": "aubergine",
             "citations": ["https://example.org"]}
            """)
        #expect(
            throws: ImportError.invalidLocalizedName(
                detail: "malformed locale tag english for eggplant")
        ) {
            try KnowledgeImporter.validate(
                localizedNames: file, against: try profiles(["eggplant"]))
        }
    }

    @Test func anEmptyNameFailsValidation() throws {
        let file = try namesFile(
            """
            {"crop": "eggplant", "locale": "en-GB", "name": "  ",
             "citations": ["https://example.org"]}
            """)
        #expect(throws: ImportError.invalidLocalizedName(detail: "empty name for eggplant")) {
            try KnowledgeImporter.validate(
                localizedNames: file, against: try profiles(["eggplant"]))
        }
    }

    @Test func missingCitationsFailValidation() throws {
        let file = try namesFile(
            """
            {"crop": "eggplant", "locale": "en-GB", "name": "aubergine", "citations": []}
            """)
        #expect(
            throws: ImportError.invalidLocalizedName(detail: "missing citations for eggplant")
        ) {
            try KnowledgeImporter.validate(
                localizedNames: file, against: try profiles(["eggplant"]))
        }
    }

    @Test func duplicateCropLocalePairsFailValidation() throws {
        let file = try namesFile(validRow + "," + validRow)
        #expect(
            throws: ImportError.invalidLocalizedName(detail: "duplicate entry eggplant en-GB")
        ) {
            try KnowledgeImporter.validate(
                localizedNames: file, against: try profiles(["eggplant"]))
        }
    }

    @Test func theCommittedBritishNamesValidateAgainstTheCommittedProfiles() throws {
        let inputs = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("knowledge/inputs", isDirectory: true)
        let file = try JSONDecoder().decode(
            LocalizedNamesFile.self,
            from: try Data(
                contentsOf: inputs.appendingPathComponent(KnowledgeImporter.localizedNamesFile)))
        let profiles = try JSONDecoder().decode(
            CropProfilesFile.self,
            from: try Data(
                contentsOf: inputs.appendingPathComponent(KnowledgeImporter.cropProfilesFile)))
        try KnowledgeImporter.validate(localizedNames: file, against: profiles)
        #expect(file.names.count == 4)
        #expect(file.names.allSatisfy { $0.locale == "en-GB" })
    }
}
