import Foundation
import GRDB

public struct DatabaseIdentityError: Error, Equatable {
    public let path: String
    public let applicationID: Int
}

public struct AppDatabase: Sendable {
    public let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) throws {
        let migrator = SchemaMigrations.migrator()
        let applied = try writer.read { try migrator.appliedIdentifiers($0) }
        try MigrationHistory.validate(applied: applied, registered: SchemaMigrations.identifiers)
        try migrator.migrate(writer)
        self.writer = writer
    }

    public static func open(at url: URL) throws -> AppDatabase {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try verifyIdentity(at: url)
        let pool = try DatabasePool(path: url.path, configuration: makeConfiguration())
        return try AppDatabase(pool)
    }

    private static func verifyIdentity(at url: URL) throws {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes?[.size] as? Int, size > 0 else {
            return
        }
        var configuration = Configuration()
        configuration.readonly = true
        let queue = try DatabaseQueue(path: url.path, configuration: configuration)
        defer { try? queue.close() }
        let (applicationID, userTableCount) = try queue.read { db in
            (
                try Int.fetchOne(db, sql: "PRAGMA application_id") ?? 0,
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COUNT(*) FROM sqlite_master
                        WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
                        """
                ) ?? 0
            )
        }
        if applicationID == SchemaMigrations.databaseApplicationID {
            return
        }
        if applicationID == 0 && userTableCount == 0 {
            return
        }
        throw DatabaseIdentityError(path: url.path, applicationID: applicationID)
    }

    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue(configuration: makeConfiguration()))
    }

    public static func defaultURL() throws -> URL {
        try FileManager.default
            .url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            .appendingPathComponent("Croft", isDirectory: true)
            .appendingPathComponent("croft.sqlite", isDirectory: false)
    }

    private static func makeConfiguration() -> Configuration {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        return configuration
    }
}
