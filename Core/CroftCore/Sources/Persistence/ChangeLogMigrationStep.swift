import GRDB

extension SchemaMigrations {
    static let applyChangeLog: @Sendable (Database) throws -> Void = { db in
        try db.execute(
            sql: """
                CREATE TABLE change_log (
                    sequence INTEGER PRIMARY KEY AUTOINCREMENT,
                    entity_kind TEXT NOT NULL CHECK (
                        entity_kind IN (
                            'property', 'garden', 'growing_area', 'bed',
                            'plant_family', 'genus', 'species', 'cultivar',
                            'pest', 'disease', 'pathogen', 'environmental_condition',
                            'seed_lot', 'starter_batch', 'planting',
                            'observation', 'observation_photo',
                            'harvest', 'task', 'daily_weather'
                        )
                    ),
                    entity_id TEXT NOT NULL,
                    operation TEXT NOT NULL CHECK (
                        operation IN ('create', 'update', 'delete')
                    ),
                    changed_at DATETIME NOT NULL
                )
                """
        )
        try db.execute(
            sql: """
                CREATE INDEX change_log_on_entity
                ON change_log(entity_kind, entity_id)
                """
        )
    }
}
