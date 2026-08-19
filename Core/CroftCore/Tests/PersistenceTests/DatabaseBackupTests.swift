import Foundation
import GRDB
import Testing

@testable import Persistence

struct DatabaseBackupTests {
    @Test func freshOpenCreatesNoBackup() throws {
        let url = try temporaryDatabaseURL()
        defer { removeDatabaseFiles(at: url) }
        _ = try AppDatabase.open(at: url)
        #expect(!FileManager.default.fileExists(atPath: backupURL(for: url).path))
    }

    @Test func noOpReopenCreatesNoBackup() throws {
        let url = try temporaryDatabaseURL()
        defer { removeDatabaseFiles(at: url) }
        try openAndClose(at: url)
        _ = try AppDatabase.open(at: url)
        #expect(!FileManager.default.fileExists(atPath: backupURL(for: url).path))
    }

    @Test func migratingAnOlderDatabaseWritesAPreMigrationBackup() throws {
        let url = try temporaryDatabaseURL()
        defer { removeDatabaseFiles(at: url) }
        let first = try #require(SchemaMigrations.identifiers.first)
        try buildDatabase(at: url, through: first)
        _ = try AppDatabase.open(at: url)
        let backup = backupURL(for: url)
        #expect(FileManager.default.fileExists(atPath: backup.path))
        let applied = try appliedIdentifiers(inBackupAt: backup)
        #expect(applied == [first])
    }

    @Test func aNewerBackupOverwritesTheOlderOne() throws {
        let url = try temporaryDatabaseURL()
        defer { removeDatabaseFiles(at: url) }
        let identifiers = SchemaMigrations.identifiers
        let first = try #require(identifiers.first)
        try #require(identifiers.count >= 2)
        try buildDatabase(at: url, through: first)
        _ = try AppDatabase.open(at: url)
        removeDatabaseFiles(at: url, keepingBackup: true)
        try buildDatabase(at: url, through: identifiers[1])
        _ = try AppDatabase.open(at: url)
        let applied = try appliedIdentifiers(inBackupAt: backupURL(for: url))
        #expect(applied == Set(identifiers.prefix(2)))
    }

    private func temporaryDatabaseURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("croft.sqlite", isDirectory: false)
    }

    private func backupURL(for url: URL) -> URL {
        url.deletingLastPathComponent()
            .appendingPathComponent(
                url.lastPathComponent + ".pre-migration", isDirectory: false)
    }

    private func buildDatabase(at url: URL, through identifier: String) throws {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        let queue = try DatabaseQueue(path: url.path, configuration: configuration)
        try SchemaMigrations.migrator(through: identifier).migrate(queue)
        try queue.close()
    }

    private func openAndClose(at url: URL) throws {
        _ = try AppDatabase.open(at: url)
    }

    private func appliedIdentifiers(inBackupAt url: URL) throws -> Set<String> {
        let queue = try DatabaseQueue(path: url.path, configuration: Configuration())
        defer { try? queue.close() }
        return try queue.read { try SchemaMigrations.migrator().appliedIdentifiers($0) }
    }

    private func removeDatabaseFiles(at url: URL, keepingBackup: Bool = false) {
        let manager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            try? manager.removeItem(atPath: url.path + suffix)
        }
        if !keepingBackup {
            try? manager.removeItem(at: url.deletingLastPathComponent())
        }
    }
}
