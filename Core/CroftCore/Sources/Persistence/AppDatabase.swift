import Foundation
import GRDB

public struct DatabaseIdentityError: Error, Equatable {
    public let path: String
    public let applicationID: Int
}

public struct AppDatabase: Sendable {
    public let writer: any DatabaseWriter
    public let recordsChanges: Bool

    public init(_ writer: any DatabaseWriter, recordingChanges: Bool = true) throws {
        let migrator = SchemaMigrations.migrator()
        let applied = try writer.read { try migrator.appliedIdentifiers($0) }
        try MigrationHistory.validate(applied: applied, registered: SchemaMigrations.identifiers)
        try migrator.migrate(writer)
        self.writer = writer
        recordsChanges = recordingChanges
    }

    public static func open(at url: URL) throws -> AppDatabase {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try verifyHeader(at: url)
        let pool = try DatabasePool(path: url.path, configuration: makeConfiguration())
        try verifyOpenedIdentity(of: pool, path: url.path)
        let database = try AppDatabase(pool)
        try? pool.writeWithoutTransaction { try $0.checkpoint(.truncate) }
        return database
    }

    static func verifyHeader(at url: URL) throws {
        let target = url.resolvingSymlinksInPath()
        guard let handle = try? FileHandle(forReadingFrom: target) else {
            return
        }
        defer { try? handle.close() }
        guard let header = try handle.read(upToCount: 100), header.count == 100 else {
            try requireOwnershipEvidence(at: target, reportedPath: url.path)
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
            try requireOwnershipEvidence(at: target, reportedPath: url.path)
            return
        }
        throw DatabaseIdentityError(path: url.path, applicationID: applicationID)
    }

    private static func requireOwnershipEvidence(at target: URL, reportedPath: String) throws {
        if walApplicationID(at: target) == SchemaMigrations.databaseApplicationID {
            return
        }
        for suffix in ["-wal", "-journal"] {
            let sidecar = target.path + suffix
            guard
                let attributes = try? FileManager.default.attributesOfItem(atPath: sidecar)
            else {
                continue
            }
            guard attributes[.type] as? FileAttributeType == .typeRegular else {
                throw DatabaseIdentityError(path: reportedPath, applicationID: 0)
            }
            if let size = attributes[.size] as? Int, size > 0 {
                throw DatabaseIdentityError(path: reportedPath, applicationID: 0)
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

    public static func inMemory(recordingChanges: Bool = true) throws -> AppDatabase {
        try AppDatabase(
            DatabaseQueue(configuration: makeConfiguration()),
            recordingChanges: recordingChanges
        )
    }

    public static func openReadOnly(at url: URL) throws -> AppDatabase {
        var configuration = makeConfiguration()
        configuration.readonly = true
        let queue = try DatabaseQueue(path: url.path, configuration: configuration)
        let (applicationID, applied) = try queue.read { db in
            (
                try Int.fetchOne(db, sql: "PRAGMA application_id") ?? 0,
                try SchemaMigrations.migrator().appliedIdentifiers(db)
            )
        }
        guard applicationID == SchemaMigrations.databaseApplicationID else {
            throw DatabaseIdentityError(path: url.path, applicationID: applicationID)
        }
        try MigrationHistory.validate(applied: applied, registered: SchemaMigrations.identifiers)
        guard Set(SchemaMigrations.identifiers).isSubset(of: applied) else {
            throw DatabaseIdentityError(
                path: url.path, applicationID: SchemaMigrations.databaseApplicationID)
        }
        return AppDatabase(readOnly: queue)
    }

    private init(readOnly writer: any DatabaseWriter) {
        self.writer = writer
        recordsChanges = false
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

extension AppDatabase {
    private struct WALHeader {
        let pageSize: Int
        let bigEndianWords: Bool
        let salt: Data
        let checksum: (UInt32, UInt32)
    }

    private static func walApplicationID(at target: URL) -> Int? {
        guard let handle = openRegularFile(atPath: target.path + "-wal") else {
            return nil
        }
        defer { try? handle.close() }
        guard
            let bytes = try? handle.read(upToCount: 32), bytes.count == 32,
            let header = validWALHeader(bytes)
        else {
            return nil
        }
        return committedPageOneApplicationID(handle, header)
    }

    private static func validWALHeader(_ bytes: Data) -> WALHeader? {
        let magic = headerField(bytes, at: 0)
        guard magic == 0x377F_0682 || magic == 0x377F_0683 else {
            return nil
        }
        guard headerField(bytes, at: 4) == 3_007_000 else {
            return nil
        }
        let bigEndianWords = magic & 1 == 1
        let pageSize = Int(headerField(bytes, at: 8))
        guard pageSize >= 512, pageSize <= 65536, pageSize & (pageSize - 1) == 0 else {
            return nil
        }
        let checksum = walChecksum((0, 0), bytes.prefix(24), bigEndianWords)
        guard checksum == (headerField(bytes, at: 24), headerField(bytes, at: 28)) else {
            return nil
        }
        return WALHeader(
            pageSize: pageSize,
            bigEndianWords: bigEndianWords,
            salt: bytes.dropFirst(16).prefix(8),
            checksum: checksum
        )
    }

    private static func committedPageOneApplicationID(
        _ handle: FileHandle,
        _ header: WALHeader
    ) -> Int? {
        let frameSize = 24 + header.pageSize
        var checksum = header.checksum
        var latest: Int?
        var committed: Int?
        var bytesScanned = 32
        while let frame = try? handle.read(upToCount: frameSize), frame.count == frameSize {
            bytesScanned += frameSize
            guard bytesScanned <= walScanLimit else {
                break
            }
            guard frame.dropFirst(8).prefix(8).elementsEqual(header.salt) else {
                break
            }
            let pageNumber = headerField(frame, at: 0)
            guard pageNumber != 0 else {
                break
            }
            checksum = walChecksum(checksum, frame.prefix(8), header.bigEndianWords)
            checksum = walChecksum(checksum, frame.dropFirst(24), header.bigEndianWords)
            guard checksum == (headerField(frame, at: 16), headerField(frame, at: 20)) else {
                break
            }
            if pageNumber == 1 {
                latest = Int(headerField(frame, at: 24 + 68))
            }
            if headerField(frame, at: 4) != 0 {
                committed = latest ?? committed
            }
        }
        return committed
    }

    private static let walScanLimit = 64 * 1024 * 1024

    private static func openRegularFile(atPath path: String) -> FileHandle? {
        let descriptor = Darwin.open(path, O_RDONLY | O_NONBLOCK)
        guard descriptor >= 0 else {
            return nil
        }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG else {
            Darwin.close(descriptor)
            return nil
        }
        return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }

    private static func walChecksum(
        _ seed: (UInt32, UInt32),
        _ data: Data,
        _ bigEndianWords: Bool
    ) -> (UInt32, UInt32) {
        let bytes = [UInt8](data)
        var sum1 = seed.0
        var sum2 = seed.1
        var index = 0
        while index + 8 <= bytes.count {
            sum1 = sum1 &+ walWord(bytes, index, bigEndianWords) &+ sum2
            sum2 = sum2 &+ walWord(bytes, index + 4, bigEndianWords) &+ sum1
            index += 8
        }
        return (sum1, sum2)
    }

    private static func walWord(_ bytes: [UInt8], _ offset: Int, _ bigEndian: Bool) -> UInt32 {
        let ordered =
            bigEndian
            ? (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
            : (bytes[offset + 3], bytes[offset + 2], bytes[offset + 1], bytes[offset])
        return UInt32(ordered.0) << 24 | UInt32(ordered.1) << 16
            | UInt32(ordered.2) << 8 | UInt32(ordered.3)
    }
}
