import Foundation
import GRDB
import Testing

@testable import Persistence

struct DatabaseIdentityTests {
    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("croft.sqlite", isDirectory: false)
    }

    private func removeDatabaseDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    @Test func foreignDatabaseIsRejectedAndLeftByteIdentical() throws {
        let url = temporaryDatabaseURL()
        defer { removeDatabaseDirectory(url) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let foreign = try DatabaseQueue(path: url.path)
        try foreign.write { db in
            try db.execute(sql: "CREATE TABLE ledger (id TEXT PRIMARY KEY NOT NULL)")
            try db.execute(sql: "INSERT INTO ledger (id) VALUES ('entry')")
        }
        try foreign.close()
        let before = try Data(contentsOf: url)
        #expect(throws: DatabaseIdentityError(path: url.path, applicationID: 0)) {
            _ = try AppDatabase.open(at: url)
        }
        let after = try Data(contentsOf: url)
        #expect(before == after)
        let siblings = try FileManager.default.contentsOfDirectory(
            atPath: url.deletingLastPathComponent().path
        )
        #expect(siblings == [url.lastPathComponent])
    }

    @Test func walModeForeignDatabaseIsRejectedWithoutSideFiles() throws {
        let url = temporaryDatabaseURL()
        defer { removeDatabaseDirectory(url) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let foreign = try DatabaseQueue(path: url.path)
        try foreign.inDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "CREATE TABLE ledger (id TEXT PRIMARY KEY NOT NULL)")
        }
        try foreign.close()
        let directory = url.deletingLastPathComponent().path
        let siblingsBefore = try FileManager.default.contentsOfDirectory(atPath: directory)
        let before = try Data(contentsOf: url)
        #expect(throws: DatabaseIdentityError(path: url.path, applicationID: 0)) {
            _ = try AppDatabase.open(at: url)
        }
        let after = try Data(contentsOf: url)
        #expect(before == after)
        let siblingsAfter = try FileManager.default.contentsOfDirectory(atPath: directory)
        #expect(siblingsAfter.sorted() == siblingsBefore.sorted())
    }

    @Test func crashedWALForeignDatabaseIsRejectedWithEveryFileUntouched() throws {
        let sourceURL = temporaryDatabaseURL()
        defer { removeDatabaseDirectory(sourceURL) }
        try FileManager.default.createDirectory(
            at: sourceURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let foreign = try DatabaseQueue(path: sourceURL.path)
        try foreign.inDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "CREATE TABLE ledger (id TEXT PRIMARY KEY NOT NULL)")
        }
        let url = temporaryDatabaseURL()
        defer { removeDatabaseDirectory(url) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        for suffix in ["", "-wal", "-shm"] {
            try FileManager.default.copyItem(
                atPath: sourceURL.path + suffix,
                toPath: url.path + suffix
            )
        }
        try foreign.close()
        let contents = { (suffix: String) in
            try Data(contentsOf: URL(fileURLWithPath: url.path + suffix))
        }
        let before = try ["", "-wal", "-shm"].map(contents)
        #expect(throws: DatabaseIdentityError(path: url.path, applicationID: 0)) {
            _ = try AppDatabase.open(at: url)
        }
        let after = try ["", "-wal", "-shm"].map(contents)
        #expect(before == after)
    }

    @Test func symlinkedLiveForeignWALDatabaseIsRejectedWithTargetUntouched() throws {
        let targetURL = temporaryDatabaseURL()
        defer { removeDatabaseDirectory(targetURL) }
        try FileManager.default.createDirectory(
            at: targetURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let foreign = try DatabaseQueue(path: targetURL.path)
        try foreign.inDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "CREATE TABLE ledger (id TEXT PRIMARY KEY NOT NULL)")
        }
        defer { try? foreign.close() }
        let linkURL = temporaryDatabaseURL()
        defer { removeDatabaseDirectory(linkURL) }
        try FileManager.default.createDirectory(
            at: linkURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetURL)
        let contents = { (suffix: String) in
            try Data(contentsOf: URL(fileURLWithPath: targetURL.path + suffix))
        }
        let before = try ["", "-wal", "-shm"].map(contents)
        #expect(throws: DatabaseIdentityError(path: linkURL.path, applicationID: 0)) {
            _ = try AppDatabase.open(at: linkURL)
        }
        let after = try ["", "-wal", "-shm"].map(contents)
        #expect(before == after)
    }

    @Test func croftDatabaseWithAnUncheckpointedWALIsStillAdopted() throws {
        let sourceURL = temporaryDatabaseURL()
        defer { removeDatabaseDirectory(sourceURL) }
        try FileManager.default.createDirectory(
            at: sourceURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let sourcePool = try DatabasePool(path: sourceURL.path)
        try SchemaMigrations.migrator().migrate(sourcePool)
        let url = temporaryDatabaseURL()
        defer { removeDatabaseDirectory(url) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        for suffix in ["", "-wal", "-shm"] {
            try FileManager.default.copyItem(
                atPath: sourceURL.path + suffix,
                toPath: url.path + suffix
            )
        }
        try sourcePool.close()
        let walSize =
            try FileManager.default.attributesOfItem(
                atPath: url.path + "-wal"
            )[.size] as? Int
        #expect((walSize ?? 0) > 0)
        let database = try AppDatabase.open(at: url)
        let stamped = try database.writer.read {
            try Int.fetchOne($0, sql: "PRAGMA application_id")
        }
        #expect(stamped == SchemaMigrations.databaseApplicationID)
    }

    @Test func firstOpenStampsTheMainHeaderImmediately() throws {
        let url = temporaryDatabaseURL()
        defer { removeDatabaseDirectory(url) }
        let database = try AppDatabase.open(at: url)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: 100)
        let stamped = header?.dropFirst(68).prefix(4).reduce(0) { ($0 << 8) | Int($1) }
        #expect(stamped == SchemaMigrations.databaseApplicationID)
        _ = database
    }

    @Test func secondOpenWhileTheFirstIsStillOpenSucceeds() throws {
        let url = temporaryDatabaseURL()
        defer { removeDatabaseDirectory(url) }
        let first = try AppDatabase.open(at: url)
        let second = try AppDatabase.open(at: url)
        let stamped = try second.writer.read {
            try Int.fetchOne($0, sql: "PRAGMA application_id")
        }
        #expect(stamped == SchemaMigrations.databaseApplicationID)
        _ = first
    }

    @Test func foreignDatabaseSwappedInAfterTheHeaderCheckIsStillRejected() throws {
        let url = temporaryDatabaseURL()
        defer { removeDatabaseDirectory(url) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let foreign = try DatabaseQueue(path: url.path)
        try foreign.write { db in
            try db.execute(sql: "CREATE TABLE ledger (id TEXT PRIMARY KEY NOT NULL)")
        }
        try foreign.close()
        let pool = try DatabasePool(path: url.path)
        #expect(throws: DatabaseIdentityError(path: url.path, applicationID: 0)) {
            try AppDatabase.verifyOpenedIdentity(of: pool, path: url.path)
        }
    }

    @Test func foreignApplicationIDIsRejected() throws {
        let url = temporaryDatabaseURL()
        defer { removeDatabaseDirectory(url) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let foreign = try DatabaseQueue(path: url.path)
        try foreign.write { db in
            try db.execute(sql: "PRAGMA application_id = 0x1234")
            try db.execute(sql: "CREATE TABLE ledger (id TEXT PRIMARY KEY NOT NULL)")
        }
        try foreign.close()
        #expect(throws: DatabaseIdentityError(path: url.path, applicationID: 0x1234)) {
            _ = try AppDatabase.open(at: url)
        }
    }

    @Test func zeroLengthFileIsAdopted() throws {
        let url = temporaryDatabaseURL()
        defer { removeDatabaseDirectory(url) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let database = try AppDatabase.open(at: url)
        let applied = try database.writer.read {
            try SchemaMigrations.migrator().appliedIdentifiers($0)
        }
        #expect(applied == Set(SchemaMigrations.identifiers))
    }

    @Test func existingCroftDatabaseReopens() throws {
        let url = temporaryDatabaseURL()
        defer { removeDatabaseDirectory(url) }
        _ = try AppDatabase.open(at: url)
        let reopened = try AppDatabase.open(at: url)
        let stamped = try reopened.writer.read {
            try Int.fetchOne($0, sql: "PRAGMA application_id")
        }
        #expect(stamped == SchemaMigrations.databaseApplicationID)
    }

    @Test func croftDatabaseWithFutureMigrationFailsThroughHistory() throws {
        let url = temporaryDatabaseURL()
        defer { removeDatabaseDirectory(url) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let queue = try DatabaseQueue(path: url.path)
        var migrator = SchemaMigrations.migrator()
        migrator.registerMigration("v999-future") { _ in }
        try migrator.migrate(queue)
        try queue.close()
        #expect(throws: MigrationError.unknownApplied(["v999-future"])) {
            _ = try AppDatabase.open(at: url)
        }
    }
}
