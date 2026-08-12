# The graph layer

The Graph package connects the strongly modeled domain tables. Two tables carry it: `entity`, a registry that gives every participating domain row a stable identity and type, and `relationship`, typed edges between registered entities with provenance on every edge (source, source type, confidence, notes). Foreign keys guarantee an edge can never point at a missing entity.

## Registering a domain type

Adopt `GraphEntity`, then register rows in the same transaction that writes them:

```swift
struct Plant: GraphEntity {
    static var entityType: EntityType { .plant }
    var id: String
    var entityID: String { id }
}

try database.writer.write { db in
    try plant.insert(db)
    try GraphStore.register(plant.entityRef, in: db)
}
```

Edges and queries go through `GraphStore`:

```swift
try GraphStore.relate(
    from: plant.entityRef, .susceptibleTo, to: disease.entityRef,
    provenance: Provenance(sourceType: .observation, confidence: 0.9), in: db)

let edges = try GraphStore.outgoing(from: plant.id, via: .susceptibleTo, in: db)
let diseases = try GraphStore.resolve(edges.map(\.target), as: Disease.self, in: db)
```

`resolve` works for any endpoint type that is also a GRDB record (`FetchableRecord & TableRecord`) keyed by its entity id.

## Delete semantics

Each relationship type declares what happens when an entity on the edge is deleted, via `RelationshipType.deleteRule`:

- `cascade`: the edge is a fact about the deleted entity and goes with it. This is the rule for `SUSCEPTIBLE_TO`, `HOST_OF`, and `COMPANION_WITH`, enforced by `ON DELETE CASCADE`.
- `restrictTarget`: the entity cannot be deleted while edges of this type still point at it. This is the rule for `LOCATED_IN` (you cannot delete a location that still contains things), enforced by the `entity_located_in_restrict` trigger.

Deleting the source side of any edge always cascades.

## Adding a relationship type

The type set is closed on purpose: both the Swift enum and a database CHECK constraint list every valid type, so a typo cannot mint a new edge kind. Adding one takes three steps:

1. Add the case to `RelationshipType` with a stable SCREAMING_SNAKE raw value, and decide its `deleteRule`.
2. Add a migration that rebuilds the `relationship` table CHECK constraint to include the new raw value (SQLite cannot alter a CHECK in place, so the migration recreates the table and copies rows). If the new type restricts deletes, extend the restrict trigger in the same migration.
3. Extend the delete-semantics and round-trip tests, and add a preservation test proving existing edges survive the migration.

Never change an existing raw value: it is the stored representation. The same recipe applies to `EntityType` and `SourceType`.
