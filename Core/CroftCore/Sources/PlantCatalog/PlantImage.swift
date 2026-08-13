import Foundation
import GRDB
import Persistence

public struct PlantImage: Equatable, Hashable, Sendable {
    public var file: String
    public var license: String
    public var licenseURL: String?
    public var artist: String?
    public var sourcePageURL: String

    public init(
        file: String,
        license: String,
        licenseURL: String? = nil,
        artist: String? = nil,
        sourcePageURL: String
    ) {
        self.file = file
        self.license = license
        self.licenseURL = licenseURL
        self.artist = artist
        self.sourcePageURL = sourcePageURL
    }
}

struct PlantImageStore: Sendable {
    static let catalogKind = "catalog"
    static let organismKind = "organism"

    private let database: AppDatabase

    init(_ database: AppDatabase) {
        self.database = database
    }

    func imagesByOwner() throws -> [String: PlantImage] {
        let rows = try database.writer.read { db -> [Row] in
            guard try db.tableExists("knowledge_image") else { return [] }
            return try Row.fetchAll(
                db,
                sql: """
                    SELECT owner_id, file, license, license_url, artist, source_page_url
                    FROM knowledge_image WHERE kind = ? ORDER BY owner_id, file
                    """,
                arguments: [Self.catalogKind]
            )
        }
        var images: [String: PlantImage] = [:]
        for row in rows {
            let ownerID: String = row["owner_id"]
            guard images[ownerID] == nil else { continue }
            images[ownerID] = image(from: row)
        }
        return images
    }

    func threatImages(hostID: String) throws -> [String: PlantImage] {
        let rows = try database.writer.read { db -> [Row] in
            guard try db.tableExists("knowledge_image") else { return [] }
            return try Row.fetchAll(
                db,
                sql: """
                    SELECT owner_id, file, license, license_url, artist, source_page_url
                    FROM knowledge_image
                    WHERE owner_kind IN ('pest', 'disease')
                      AND (related_id = ? OR (related_id IS NULL AND kind = ?))
                    ORDER BY owner_id, related_id IS NULL, kind, file
                    """,
                arguments: [hostID, Self.organismKind]
            )
        }
        var images: [String: PlantImage] = [:]
        for row in rows {
            let ownerID: String = row["owner_id"]
            guard images[ownerID] == nil else { continue }
            images[ownerID] = image(from: row)
        }
        return images
    }

    private func image(from row: Row) -> PlantImage {
        PlantImage(
            file: row["file"],
            license: row["license"],
            licenseURL: Self.text(row, "license_url"),
            artist: Self.text(row, "artist"),
            sourcePageURL: row["source_page_url"]
        )
    }

    private static func text(_ row: Row, _ column: String) -> String? {
        let value: String? = row[column]
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
