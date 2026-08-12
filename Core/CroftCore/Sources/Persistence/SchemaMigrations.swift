import GRDB

public enum SchemaMigrations {
    static let migrations: [(identifier: String, apply: @Sendable (Database) throws -> Void)] = [
        (
            "v001-baseline",
            { db in
                try db.execute(sql: "PRAGMA application_id = \(databaseApplicationID)")
            }
        ),
        (
            "v002-graph",
            { db in
                try db.execute(
                    sql: """
                        CREATE TABLE entity (
                            id TEXT PRIMARY KEY NOT NULL,
                            entity_type TEXT NOT NULL CHECK (
                                entity_type IN (
                                    'plant', 'pest', 'disease',
                                    'garden_location', 'seed_lot', 'planting'
                                )
                            )
                        )
                        """
                )
                try db.execute(
                    sql: """
                        CREATE TABLE relationship (
                            id TEXT PRIMARY KEY NOT NULL,
                            from_entity_id TEXT NOT NULL
                                REFERENCES entity(id) ON DELETE CASCADE,
                            relationship_type TEXT NOT NULL CHECK (
                                relationship_type IN (
                                    'SUSCEPTIBLE_TO', 'HOST_OF',
                                    'COMPANION_WITH', 'LOCATED_IN'
                                )
                            ),
                            to_entity_id TEXT NOT NULL
                                REFERENCES entity(id) ON DELETE CASCADE,
                            source TEXT,
                            source_type TEXT CHECK (
                                source_type IN (
                                    'observation', 'reference', 'imported', 'inferred'
                                )
                            ),
                            confidence REAL CHECK (confidence BETWEEN 0.0 AND 1.0),
                            notes TEXT,
                            UNIQUE (from_entity_id, relationship_type, to_entity_id)
                        )
                        """
                )
                try db.execute(
                    sql: "CREATE INDEX relationship_from ON relationship(from_entity_id)")
                try db.execute(
                    sql: "CREATE INDEX relationship_to ON relationship(to_entity_id)")
                try db.execute(
                    sql: """
                        CREATE TRIGGER entity_located_in_restrict
                        BEFORE DELETE ON entity
                        FOR EACH ROW
                        WHEN EXISTS (
                            SELECT 1 FROM relationship
                            WHERE to_entity_id = OLD.id
                            AND relationship_type = 'LOCATED_IN'
                        )
                        BEGIN
                            SELECT RAISE(ABORT, 'entity is a LOCATED_IN target');
                        END
                        """
                )
            }
        ),
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
