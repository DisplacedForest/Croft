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
        try verifyHeader(at: url)
        let pool = try DatabasePool(path: url.path, configuration: makeConfiguration())
        try verifyOpenedIdentity(of: pool, path: url.path)
        return try AppDatabase(pool)
    }

    static func verifyHeader(at url: URL) throws {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return
        }
        defer { try? handle.close() }
        guard let header = try handle.read(upToCount: 100), header.count == 100 else {
            try requireNoPendingJournal(at: url)
            return
        }
        guard header.prefix(16).elementsEqual(sqliteHeaderMagic) else {
            return
        }
        let applicationID = Int(headerField(header, at: 68))
        if applicationID == SchemaMigrations.databaseApplicationID {
            return
        }
        let pageCount = headerField(header, at: 28)
        let changeCounter = headerField(header, at: 24)
        let versionValidFor = headerField(header, at: 92)
        if applicationID == 0 && changeCounter == versionValidFor && pageCount <= 1 {
            try requireNoPendingJournal(at: url)
            return
        }
        throw DatabaseIdentityError(path: url.path, applicationID: applicationID)
    }

    private static func requireNoPendingJournal(at url: URL) throws {
        for suffix in ["-wal", "-journal"] {
            let sidecar = url.path + suffix
            let attributes = try? FileManager.default.attributesOfItem(atPath: sidecar)
            if let size = attributes?[.size] as? Int, size > 0 {
                throw DatabaseIdentityError(path: url.path, applicationID: 0)
            }
        }
    }

    static func verifyOpenedIdentity(of writer: some DatabaseWriter, path: String) throws {
        let (applicationID, userTableCount) = try writer.writeWithoutTransaction { db in
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
        throw DatabaseIdentityError(path: path, applicationID: applicationID)
    }

    private static let sqliteHeaderMagic = Array("SQLite format 3".utf8) + [0]

    private static func headerField(_ header: Data, at offset: Int) -> UInt32 {
        header.dropFirst(offset).prefix(4).reduce(0) { ($0 << 8) | UInt32($1) }
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
