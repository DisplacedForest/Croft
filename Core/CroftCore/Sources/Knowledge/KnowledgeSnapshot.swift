import Foundation
import GRDB
import Persistence

enum KnowledgeSnapshotTables {
    static func create(in db: Database) throws {
        try db.execute(
            sql: """
                CREATE TABLE knowledge_meta (
                    key TEXT PRIMARY KEY NOT NULL,
                    value TEXT NOT NULL
                )
                """
        )
        try db.execute(
            sql: """
                CREATE TABLE knowledge_attribution (
                    record_id TEXT NOT NULL,
                    citation TEXT NOT NULL,
                    PRIMARY KEY (record_id, citation)
                )
                """
        )
    }

    static func writeMeta(_ meta: [String: String], in db: Database) throws {
        for (key, value) in meta.sorted(by: { $0.key < $1.key }) {
            try db.execute(
                sql: "INSERT INTO knowledge_meta (key, value) VALUES (?, ?)",
                arguments: [key, value]
            )
        }
    }

    static func writeAttributions(
        _ attributions: [(recordID: String, citation: String)],
        in db: Database
    ) throws {
        for attribution in attributions {
            try db.execute(
                sql: "INSERT INTO knowledge_attribution (record_id, citation) VALUES (?, ?)",
                arguments: [attribution.recordID, attribution.citation]
            )
        }
    }
}

public struct KnowledgeSnapshot {
    public let database: AppDatabase

    public enum SnapshotError: Error, Equatable {
        case missingMetaTable(String)
    }

    public static func open(at url: URL) throws -> KnowledgeSnapshot {
        let database = try AppDatabase.openReadOnly(at: url)
        let hasMeta = try database.writer.read { db in
            try db.tableExists("knowledge_meta")
        }
        guard hasMeta else {
            throw SnapshotError.missingMetaTable(url.path)
        }
        return KnowledgeSnapshot(database: database)
    }

    public func meta() throws -> [String: String] {
        try database.writer.read { db in
            var meta: [String: String] = [:]
            let rows = try Row.fetchAll(
                db, sql: "SELECT key, value FROM knowledge_meta ORDER BY key")
            for row in rows {
                meta[row["key"]] = row["value"]
            }
            return meta
        }
    }

    public func attributions(for recordID: String) throws -> [String] {
        try database.writer.read { db in
            try String.fetchAll(
                db,
                sql: """
                    SELECT citation FROM knowledge_attribution
                    WHERE record_id = ? ORDER BY citation
                    """,
                arguments: [recordID]
            )
        }
    }

    public static func logicalDump(at url: URL) throws -> String {
        let snapshot = try open(at: url)
        return try snapshot.database.writer.read { db in
            let tables = try String.fetchAll(
                db,
                sql: """
                    SELECT name FROM sqlite_master
                    WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
                    ORDER BY name
                    """
            )
            var dump = ""
            for table in tables {
                dump += "== \(table)\n"
                let columns = try db.columns(in: table).map(\.name)
                let ordering =
                    columns
                    .map { "\"\($0)\"" }
                    .joined(separator: ", ")
                let rows = try Row.fetchAll(
                    db, sql: "SELECT * FROM \"\(table)\" ORDER BY \(ordering)")
                for row in rows {
                    let cells = columns.map { "\(row[$0] as DatabaseValue? ?? .null)" }
                    dump += cells.joined(separator: "|") + "\n"
                }
            }
            return dump
        }
    }
}
