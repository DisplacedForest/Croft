import Foundation
import GRDB

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
        let pool = try DatabasePool(path: url.path, configuration: makeConfiguration())
        return try AppDatabase(pool)
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
