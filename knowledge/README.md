# Knowledge snapshot

Croft ships a read-only SQLite knowledge snapshot so the app can answer basic
plant questions offline. The snapshot is built deterministically from the
pinned inputs in `inputs/` by the `knowledge-importer` tool in
`Core/CroftCore`.

## Rebuilding from a clean checkout

```sh
mise run knowledge
```

That builds `App/Shared/Resources/knowledge.sqlite` (gitignored, bundled into
the apps at build time) and regenerates `ATTRIBUTION.md`. `mise run build`
depends on it, so a normal app build always has a fresh snapshot. The importer
verifies every input against `inputs/inputs.lock.json` and refuses to run on a
checksum mismatch.

Two runs over the same inputs produce identical logical content, proven by
tests in `Core/CroftCore/Tests/KnowledgeTests`. Determinism is defined over
the dumped table content (`knowledge-importer dump`), not file bytes, since
byte layout can vary across SQLite builds.

## Inputs

- `crop-profiles.json`: first-party species-level growing profiles with
  per-record citations. Committed as is.
- `pest-disease-cultivar-seed.sanitized.json`: first-party editorial pest,
  disease, and cultivar-resistance seed data with citations. The resistance
  examples in the raw file carry vendor image references, so it is committed
  only in sanitized form.
- `cultivar-catalog.sanitized.json`: cultivar facts derived from vendor
  catalogs, committed only in sanitized form.

The sanitizer strips price, flavor_profile, vendor, url, image_url,
image_file, and image_shared. Those fields never enter the repository or the
snapshot, and a test greps the committed inputs to keep it that way.

## Updating an input

1. Replace the source file. For the sanitized inputs, run
   `swift run --package-path Core/CroftCore knowledge-importer sanitize catalog <raw> inputs/cultivar-catalog.sanitized.json`
   or
   `swift run --package-path Core/CroftCore knowledge-importer sanitize pest-disease <raw> inputs/pest-disease-cultivar-seed.sanitized.json`.
2. Update the matching SHA-256 in `inputs/inputs.lock.json` (the sanitize
   command prints both raw and sanitized checksums; the raw checksum is
   recorded under `upstream`).
3. Run `mise run knowledge` and commit the input, the lock, and the
   regenerated `ATTRIBUTION.md` together.

## Import policy

- Records that violate domain or graph integrity (unknown hosts, unknown
  disease or pest references, unmappable pathogen types, checksum mismatches)
  fail the import with the offending record named.
- Policy skips are counted and printed, never silent: catalog rows for crops
  outside the 32 profiled species, the ambiguous `squash` crop slug (a
  cultivar belongs to one species; hosts fan out to both squash species
  instead), unparseable spacing text, and vendor tags with no model home.
- Vendor rows merge by crop and cultivar slug. Cultivar-specific maturity data
  is preferred over coarse buckets, structured-tag spacing is preferred over
  prose, list fields union, and an explicit heirloom flag beats a conflicting
  seed-type tag (the tag is dropped and counted).
- Units are canonical metric: Fahrenheit converts to Celsius, inches to
  centimeters, both rounded to one decimal.

## Attribution

`ATTRIBUTION.md` is generated from the snapshot's `knowledge_attribution` and
`knowledge_meta` tables and carries every citation present in the source
records plus each input's provenance statement. Do not edit it by hand.
