import Foundation
import Knowledge

extension KnowledgeFixture {
    static func fileNames(in entry: String) -> [String] {
        entry.components(separatedBy: "\"file\": \"").dropFirst().compactMap {
            $0.split(separator: "\"").first.map(String.init)
        }
    }

    static func threatFixture(_ entries: [String]) throws -> KnowledgeFixture {
        var files = imageFiles
        for entry in entries {
            for name in fileNames(in: entry) {
                files[name] = imageBytes
            }
        }
        return try KnowledgeFixture(
            images: manifest(extraEntries: entries), imageFiles: files)
    }

    static func threatEntry(
        slug: String,
        ownerKind: String,
        kind: String,
        file: String,
        relatedSlug: String? = nil
    ) -> String {
        let related = relatedSlug.map { "\"related_slug\": \"\($0)\"," } ?? ""
        return """
            {
              "slug": "\(slug)",
              "owner_kind": "\(ownerKind)",
              "kind": "\(kind)",
              \(related)
              "file": "\(file)",
              "sha256": "\(imageChecksum)",
              "source_title": "File:\(file)",
              "source_page_url": "https://example.org/wiki/\(file)",
              "source_file_url": "https://example.org/files/\(file)",
              "license": "CC BY 2.0",
              "license_url": "https://creativecommons.org/licenses/by/2.0/",
              "artist": "A Photographer"
            }
            """
    }

    static let threatEntries = [
        threatEntry(
            slug: "pest/tomato-hornworm", ownerKind: "pest", kind: "organism",
            file: "hornworm.jpg"),
        threatEntry(
            slug: "pest/tomato-hornworm", ownerKind: "pest", kind: "damage",
            file: "hornworm-damage.jpg", relatedSlug: "tomato"),
        threatEntry(
            slug: "disease/early-blight", ownerKind: "disease", kind: "organism",
            file: "early-blight.jpg"),
        threatEntry(
            slug: "disease/early-blight", ownerKind: "disease", kind: "symptom",
            file: "early-blight-tomato.jpg", relatedSlug: "tomato"),
    ]

    static let manifestTail = "\n  ]\n}"

    static func manifest(extraEntries: [String]) -> String {
        guard !extraEntries.isEmpty else { return images }
        guard let tail = images.range(of: manifestTail, options: .backwards) else {
            return images
        }
        let inserted = extraEntries.joined(separator: ",\n")
        return images.replacingCharacters(in: tail, with: ",\n\(inserted)\(manifestTail)")
    }

    static let imagesWithThreats = manifest(extraEntries: threatEntries)
}
