# Adding a migration

Migrations live in `Sources/Persistence/SchemaMigrations.swift` as an ordered,
append-only list. `AppDatabase` runs every unapplied migration in order,
transactionally, whenever a database is opened.

## Rules

- Append only. Never edit, rename, remove, or reorder a shipped migration.
  A database whose applied history does not match the registry fails loudly
  at open instead of continuing.
- Migrations only move forward. There is no downgrade path, and a user
  database is never deleted and recreated.
- Personal-graph tables use client-generated UUIDs stored as `TEXT PRIMARY
  KEY NOT NULL`. Never use `AUTOINCREMENT` or rely on `rowid` for identity.
- References to canonical knowledge use the snapshot's stable canonical IDs,
  not rowids, per ADR 1.
- Table and column names are `snake_case`.

## Steps

1. Append an entry to `SchemaMigrations.migrations` with the next identifier
   in the `vNNN-description` sequence.
2. Add a preservation test in `Tests/PersistenceTests` using
   `MigrationHarness`: build the database through the previous identifier,
   seed representative data, call `migrateToHead`, and assert the data
   survives.
3. Run `mise run check`. Migration tests run in CI on every pull request.
