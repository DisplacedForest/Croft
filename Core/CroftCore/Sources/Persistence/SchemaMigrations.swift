import GRDB

public enum SchemaMigrations {
    static let migrations: [(identifier: String, apply: @Sendable (Database) throws -> Void)] = [
        ("v001-baseline", applyBaseline),
        ("v002-graph", applyGraph),
        ("v003-taxonomy", applyTaxonomy),
        ("v004-garden-structure", applyGardenStructure),
        ("v005-pests", applyPests),
        ("v006-plant-relationships", applyPlantRelationships),
        ("v007-diseases", applyDiseases),
        ("v008-seed-lots", applySeedLots),
        ("v009-plantings", applyPlantings),
        ("v010-cultivation-profile", applyCultivationProfile),
        ("v011-knowledge-types", applyKnowledgeTypes),
        ("v015-edge-cardinality", applyEdgeCardinality),
        ("v012-observations", applyObservations),
        ("v013-harvests", applyHarvests),
        ("v014-garden-tasks", applyGardenTasks),
        ("v016-lifecycle-stages", applyLifecycleStages),
        ("v017-property-location", applyPropertyLocation),
        ("v018-harvest-yield", applyHarvestYield),
        ("v019-daily-weather", applyDailyWeather),
        ("v020-change-log", applyChangeLog),
        ("v021-hardiness-zone-text", applyHardinessZoneText),
        ("v022-climate-provenance", applyClimateProvenance),
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
