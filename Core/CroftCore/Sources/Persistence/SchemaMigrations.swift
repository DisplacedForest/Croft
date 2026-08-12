import GRDB

public enum SchemaMigrations {
    static let migrations: [(identifier: String, apply: @Sendable (Database) throws -> Void)] = [
        (
            "v001-baseline",
            { db in
                try db.execute(sql: "PRAGMA application_id = \(databaseApplicationID)")
            }
        )
    ]

    public static let identifiers: [String] = migrations.map(\.identifier)

    public static let databaseApplicationID = 0x4352_4F46

    public static func migrator(through identifier: String? = nil) -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        for migration in migrations {
            migrator.registerMigration(migration.identifier, migrate: migration.apply)
            if migration.identifier == identifier {
                break
            }
        }
        return migrator
    }
}
