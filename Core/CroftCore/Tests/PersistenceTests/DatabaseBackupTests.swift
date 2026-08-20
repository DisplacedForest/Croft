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

    @Test func commitsStillInTheWALAreIncludedInTheBackup() throws {
        let url = try temporaryDatabaseURL()
        defer { removeDatabaseFiles(at: url) }
        let first = try #require(SchemaMigrations.identifiers.first)
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        let fixture = try DatabaseQueue(path: url.path, configuration: configuration)
        try fixture.writeWithoutTransaction { db in
            _ = try String.fetchOne(db, sql: "PRAGMA journal_mode=WAL")
        }
        try SchemaMigrations.migrator(through: first).migrate(fixture)
        try fixture.write { db in
            try db.execute(sql: "CREATE TABLE backupProbe(id INTEGER PRIMARY KEY)")
        }
        let reader = try DatabaseQueue(path: url.path, configuration: configuration)
        try reader.writeWithoutTransaction { db in
            try db.execute(sql: "BEGIN")
            _ = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM backupProbe")
            try fixture.write { fixtureDb in
                try fixtureDb.execute(sql: "INSERT INTO backupProbe(id) VALUES (1)")
            }
            _ = try AppDatabase.open(at: url)
            try db.execute(sql: "COMMIT")
        }
        try reader.close()
        let backup = backupURL(for: url)
        let queue = try DatabaseQueue(path: backup.path, configuration: Configuration())
        defer { try? queue.close() }
        let probe = try queue.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM backupProbe")
        }
        #expect(probe == 1)
    }

    @Test func aFailedBackupKeepsThePreviousOne() throws {
        let url = try temporaryDatabaseURL()
        defer { removeDatabaseFiles(at: url) }
        let identifiers = SchemaMigrations.identifiers
        let first = try #require(identifiers.first)
        try buildDatabase(at: url, through: first)
        _ = try AppDatabase.open(at: url)
        let backup = backupURL(for: url)
        let before = try Data(contentsOf: backup)
        removeDatabaseFiles(at: url, keepingBackup: true)
        try buildDatabase(at: url, through: identifiers[1])
        let staging = url.deletingLastPathComponent()
            .appendingPathComponent(
                url.lastPathComponent + ".pre-migration-staging", isDirectory: false)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: staging.path)
        defer {
            try? FileManager.default.setAttributes(
                [.immutable: false], ofItemAtPath: staging.path)
            try? FileManager.default.removeItem(at: staging)
        }
        #expect(throws: (any Error).self) {
            _ = try AppDatabase.open(at: url)
        }
        #expect(try Data(contentsOf: backup) == before)
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
