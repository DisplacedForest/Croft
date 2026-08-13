import Foundation
import Knowledge

extension KnowledgeFixture {
    static let imageBytes = Data([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
    ])

    static let imageChecksum = InputsLock.checksum(of: imageBytes)

    static let imageFiles: [String: Data] = [
        "tomato.jpg": imageBytes,
        "brandywine.jpg": imageBytes,
    ]

    static let images = """
        {
          "meta": {"name": "plant-images", "version": "1", "provenance": "fixture images"},
          "images": [
            {
              "slug": "tomato",
              "owner_kind": "species",
              "kind": "catalog",
              "file": "tomato.jpg",
              "sha256": "\(imageChecksum)",
              "source_title": "File:Tomato.jpg",
              "source_page_url": "https://example.org/wiki/File:Tomato.jpg",
              "source_file_url": "https://example.org/files/Tomato.jpg",
              "license": "CC BY 2.0",
              "license_url": "https://creativecommons.org/licenses/by/2.0/",
              "artist": "A Photographer"
            },
            {
              "slug": "tomato/brandywine",
              "owner_kind": "cultivar",
              "kind": "catalog",
              "file": "brandywine.jpg",
              "sha256": "\(imageChecksum)",
              "source_title": "File:Brandywine.jpg",
              "source_page_url": "https://example.org/wiki/File:Brandywine.jpg",
              "source_file_url": "https://example.org/files/Brandywine.jpg",
              "license": "CC0",
              "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
              "artist": "Another Photographer"
            }
          ]
        }
        """
}
