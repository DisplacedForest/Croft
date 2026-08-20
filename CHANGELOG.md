# Changelog

All notable changes to Croft are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- Before applying schema migrations to an existing garden database, Croft now
  writes a rolling pre-migration backup beside it, and opening a database
  written by a newer version of Croft explains that the app needs updating
  instead of showing a raw migration error. Development builds keep to their
  own croft-dev.sqlite and can never touch the installed app's data.
- A search field on every crop page filters its varietals live by bare name,
  full vendor name, or binomial, with a plain empty state when nothing
  matches.
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

- First-run property setup can no longer vanish forever: the prompted flag is
  written only when you save or choose Not Now, so a setup sheet closed by
  anything other than you returns on the next launch. If the sheet ever opens
  before its form is ready, it shows a loading indicator instead of an empty
  card.
- The hardiness zone field accepts lettered USDA zones like 8a and 8b, stores
  the letter, and shows it back unchanged. A derived zone whose number matches
  your lettered entry no longer nags with a suggestion.
- Development builds no longer pop an "Unable to Check For Updates" dialog
  at launch. The updater only starts when the app carries a Developer ID
  signature; otherwise Check for Updates stays visible but disabled, with a
  note that updates need a signed build.
- A fresh install shows the property setup sheet again on first launch; a
  capture plumbing change had stopped it from ever appearing.
- Switching sections no longer washes the window in that section's color.
  The background and chrome stay one constant surface everywhere, and the
  domain palette shows up only as accents: sidebar icons, dots, badges, and
  small highlights.
- Pest and disease text on a plant page now speaks about that plant. Damage
  and symptom notes written for a specific host render on that host's page,
  organism descriptions read host-neutral everywhere else, and no page
  lectures you about some other crop's problems.
- Varietal rows show a photo only when the varietal has its own image; the
  rest carry a quiet leaf placeholder instead of repeating the species photo
  down the whole list. The detail page keeps its species fallback.
- The eye and basket buttons on the planting page now open observation and
  harvest capture prefilled with that planting on macOS, instead of doing
  nothing.
- The summer squash and winter squash pages now list their varietals. The
  catalog filed all 116 squash cultivars under a generic squash label that
  mapped to neither crop; they now classify by type into summer squash (40),
  winter squash (37), and pumpkin (24), with the 15 ornamental gourds and
  luffas counted out of scope rather than silently dropped.
- When weather can't load, Today now says so quietly instead of showing
  nothing: one line tells you whether a property location is missing or the
  weather service is unavailable. Property setup is equally honest when zone
  and frost dates can't be derived from weather history.
- Planting rows everywhere now lead with the crop (Carrot, Pepper) and show
  the varietal small in the subtitle, so beds read at a glance; the planting
  detail page still heroes the varietal.
- Season view cards now show the crop or varietal name for every planting,
  including ones recorded before 0.2.0, instead of "Unknown plant".
- Navigating between Today, Garden, bed detail, and plant pages no longer
  reads as a background shift: every level frames its content in the same
  centered column, and the garden structure and property sheets sit on the
  app surface instead of the system background, in light and dark mode.
- The property location form no longer repeats the matched address in a
  caption under the search field, and Use Current Location now fills in a
  readable address for the spot and derives your zone and frost dates just
  like address search does. When no address exists for the coordinate, the
  form says so instead of staying silent.
- Varietal rows on a crop page now read as the varietal alone ("Blue Spice",
  "Roma (Organic)") instead of repeating the crop in every row and binomial
  line; searching by the full vendor name still works.
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
