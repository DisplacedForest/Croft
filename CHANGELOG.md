# Changelog

All notable changes to Croft are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- Cultivar imagery grown from 11 to 43 varietals across sixteen crops, each
  image individually licensed (public domain, CC0, or CC BY) and attributed,
  so more cultivar pages show their own look instead of the species fallback.
- Companion advisories at bed assignment: picking a bed tells you when the
  plant is a companion or antagonist of something already growing there,
  naming the plant and the source, never blocking the save.
- A frost alert at the top of Today when the next two nights dip to a level
  your plants care about, naming the at-risk plantings and their beds with
  the forecast low. Tolerances come from each plant's profile and are never
  guessed; no coordinates or no tender plantings means no alert.
- Property setup by address: search any address or place with live
  suggestions, and the matched coordinate derives a hardiness zone and frost
  dates from ten years of weather history as prefills you confirm or edit,
  never silent writes. Today's weather now follows the property's location
  when one is set, with device location as the fallback.

- Observations can record a typed lifecycle stage (germinated, transplanted,
  first flower, first fruit set, pulled) alongside the note.
- Property settings for location, hardiness zone, and last and first frost
  dates, with a one-time first-run setup prompt.
- A season view under Garden: planting windows computed from your frost dates
  and each plant's profile, what is plantable now and coming up with reasons,
  the year at a glance, and planned plantings created straight from the list.
- A rotation warning when assigning a planting to a bed that held the same
  plant family in the last three seasons, with the bed's recent family history
  shown while planning and an honest note when nothing is recorded yet.
- Harvests record a harvested part and structured yield in any mass, volume,
  or count unit, entered in your preferred measurement system, with totals
  that add up across units and a first-harvest date on the planting timeline.
- The Record menu reaches every capture action from anywhere with keyboard
  shortcuts, prefills targets from the screen you are on with an override
  picker in each sheet, records a lifecycle stage on the visible planting in
  two clicks, and photos now paste from the clipboard as well as drag and
  drop.
- The planting page tells the whole season as one timeline: planted with its
  lineage, stage pills with day counts, observations with notes and photos,
  harvests with yields, and the first harvest called out with days from
  sowing, plus header stats for days to first harvest and total yield.
- Today is a ranked attention list: overdue and due tasks completable in
  place, harvest checks past expected maturity, what is plantable now,
  plantings gone quiet, and a Recently card, each with its reason, capped so
  a busy June stays readable. The weather chip opens a seven-day forecast,
  and a quiet winter day says so calmly instead of showing a blank page.
- Croft updates itself: releases are offered in the app through Sparkle, with
  a Check for Updates menu item and scheduled background checks you consent
  to on first launch.
- The catalog speaks British English on British systems: aubergine, courgette,
  beetroot, and sweetcorn appear first on en-GB, and searching either the
  British or American name finds the crop everywhere, on any system.
- The plant catalog opens on plain-English crops (Tomato, Strawberry, Corn)
  with images and varietal counts instead of a flat list of 1,159 cultivar
  names; open a crop to browse its varietals, and search finds crops and
  varietals from anywhere by common name, varietal name, or binomial.

- Threat pages now show what an attack looks like on your crop: early blight
  lesions on tomato leaves, and the imported cabbageworm on kale as
  caterpillar, frass, and feeding damage, each preferred over the generic
  organism photo on the matching plant page.

### Fixed

- The property location form no longer repeats the matched address in a
  caption under the search field, and Use Current Location now fills in a
  readable address for the spot and derives your zone and frost dates just
  like address search does. When no address exists for the coordinate, the
  form says so instead of staying silent.
- The Record menu now stays in the toolbar on bed, planting, and plant detail
  screens instead of disappearing when you navigate into them.
- A property record Croft can't read now shows an explicit message in
  Settings instead of posing as a fresh install, first-run setup stays out of
  the way so the stored record can't be overwritten, and a save that reaches
  the database no longer reports failure.

## 0.1.0 - 2026-08-18

### Added

- Plant taxonomy: family, genus, species, and cultivar with typed cultivation
  attributes (life cycle, sun, water, soil pH, spacing, germination, sowing,
  frost tolerance, maturity), stored locally in SQLite.
- Garden structure: properties, gardens, growing areas, and beds (raised,
  in-ground, container) with graph-backed containment, renames, moves, and
  archiving.
- Plantings connecting crops to beds with a planned-to-finished lifecycle,
  transplant handling, and propagation lineage from seed lots and starter
  batches.
- Seed lots and starter batches with graph lineage back to their cultivar.
- Pests, beneficials, diseases, pathogens, and environmental conditions as
  typed graph entities, with host, susceptibility, vector, and cultivar
  resistance relationships.
- Plant-to-plant relationships (companion, antagonist, rotation) that require
  source provenance.
- A deterministic knowledge importer producing the bundled offline snapshot:
  32 crops with metric cultivation profiles, over a thousand cultivars, 31
  pests, 37 diseases, typed relationships, and per-record citations, built
  from pinned, checksum-verified, sanitized inputs.
- Bundled identification imagery for plants, pests, and diseases, all public
  domain, CC0, or CC BY, with per-image attribution generated into
  knowledge/ATTRIBUTION.md.
- Observations with notes, graph targeting, and photo storage.
- Harvests with per-unit aggregation and planting lineage.
- Garden tasks with typed verbs, optional graph targets, due dates, and
  completion.
- App shell with a Today screen (date, local weather, due and overdue tasks),
  a garden view down to bed and planting detail, and plant pages with browse,
  search, and per-plant detail from the bundled catalog.
- Capture flows on macOS for plantings, observations (photos via file picker
  and drag and drop), harvests, tasks, and seed lots, with last-used defaults
  and keyboard shortcuts.

### Fixed

- The app refuses to adopt a foreign SQLite file as its database.
- Unknown enum raw values in stored rows fail loudly instead of decoding to
  nil.
- Species and cultivars register as graph entities on insert, so
  repository-created plants are immediately visible to relationship queries.
- Single-cardinality graph edges are enforced with partial unique indexes.
- Project generation orders after the knowledge snapshot build, removing a
  build race.
