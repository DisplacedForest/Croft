import Foundation
import Testing

@testable import Knowledge

struct ImageFieldCase: Sendable {
    let field: String
    let json: String

    static let all: [ImageFieldCase] = [
        ImageFieldCase(field: "file", json: "\"file\": \"tomato.jpg\""),
        ImageFieldCase(field: "sha256", json: "\"sha256\": \"\(KnowledgeFixture.imageChecksum)\""),
        ImageFieldCase(field: "license", json: "\"license\": \"CC BY 2.0\""),
        ImageFieldCase(
            field: "license_url",
            json: "\"license_url\": \"https://creativecommons.org/licenses/by/2.0/\""),
        ImageFieldCase(field: "artist", json: "\"artist\": \"A Photographer\""),
        ImageFieldCase(
            field: "source_page_url",
            json: "\"source_page_url\": \"https://example.org/wiki/File:Tomato.jpg\""),
        ImageFieldCase(
            field: "source_file_url",
            json: "\"source_file_url\": \"https://example.org/files/Tomato.jpg\""),
    ]
}

struct ImageValidationTests {
    private func fixture(
        replacing old: String = "",
        with new: String = "",
        extraFiles: [String: Data] = [:]
    ) throws -> KnowledgeFixture {
        let manifest =
            old.isEmpty
            ? KnowledgeFixture.images
            : KnowledgeFixture.images.replacingOccurrences(of: old, with: new)
        var files = KnowledgeFixture.imageFiles
        for (name, data) in extraFiles {
            files[name] = data
        }
        return try KnowledgeFixture(images: manifest, imageFiles: files)
    }

    @Test(arguments: [
        "CC BY-SA 4.0", "CC BY-NC 2.0", "CC BY-NC-SA 4.0", "CC BY-ND 3.0",
        "WTFPL", "All rights reserved", "cc by 2.0",
    ])
    func aDisallowedLicenseFailsTheImport(license: String) throws {
        let fixture = try fixture(
            replacing: "\"license\": \"CC BY 2.0\"", with: "\"license\": \"\(license)\"")
        #expect(throws: ImportError.disallowedImageLicense(slug: "tomato", license: license)) {
            try fixture.build()
        }
    }

    @Test(arguments: ImageFieldCase.all)
    func anEmptyRequiredFieldFailsTheImport(field: ImageFieldCase) throws {
        let key = String(field.json.split(separator: ":")[0])
        let fixture = try fixture(replacing: field.json, with: "\(key): \"\"")
        #expect(throws: ImportError.invalidImageField(slug: "tomato", field: field.field)) {
            try fixture.build()
        }
    }

    @Test(arguments: ImageFieldCase.all)
    func aWhitespaceOnlyRequiredFieldFailsTheImport(field: ImageFieldCase) throws {
        let key = String(field.json.split(separator: ":")[0])
        let fixture = try fixture(replacing: field.json, with: "\(key): \"   \"")
        #expect(throws: ImportError.invalidImageField(slug: "tomato", field: field.field)) {
            try fixture.build()
        }
    }

    @Test(arguments: ["artist", "license_url"])
    func aNullOptionalFieldFailsTheImport(field: String) throws {
        let original = ImageFieldCase.all.first { $0.field == field }
        let json = try #require(original?.json)
        let key = String(json.split(separator: ":")[0])
        let fixture = try fixture(replacing: json, with: "\(key): null")
        #expect(throws: ImportError.invalidImageField(slug: "tomato", field: field)) {
            try fixture.build()
        }
    }

    @Test func anOrphanImageFileFailsTheImport() throws {
        let fixture = try fixture(extraFiles: ["stray.jpg": KnowledgeFixture.imageBytes])
        #expect(throws: ImportError.orphanImageFile("stray.jpg")) {
            try fixture.build()
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.output.path))
    }

    @Test func aHiddenFileIsNotTreatedAsAnOrphan() throws {
        let fixture = try fixture(extraFiles: [".DS_Store": Data([0x00])])
        let summary = try fixture.build()
        #expect(summary.counts["images"] == 2)
    }

    @Test func everyAllowedLicenseIsAccepted() throws {
        for license in KnowledgeImporter.allowedImageLicenses.sorted() {
            let fixture = try fixture(
                replacing: "\"license\": \"CC BY 2.0\"", with: "\"license\": \"\(license)\"")
            let summary = try fixture.build()
            #expect(summary.counts["images"] == 2)
        }
    }
}
