<img src=".github/assets/readme_header.png" alt="Croft: organize, plan, grow with purpose" width="100%">

[![CI](https://github.com/DisplacedForest/Croft/actions/workflows/ci.yml/badge.svg)](https://github.com/DisplacedForest/Croft/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/DisplacedForest/Croft?include_prereleases)](https://github.com/DisplacedForest/Croft/releases)
[![License](https://img.shields.io/github/license/DisplacedForest/Croft)](LICENSE)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![Platform macOS](https://img.shields.io/badge/platform-macOS-blue)

Open-source, local-first garden operating system built on a horticultural knowledge graph. Native Swift and SwiftUI for macOS.

## What Croft does

Croft models a real garden and the knowledge to run it, entirely on your machine. Everything lives in a local SQLite database. There's no account, no sync service, and no network dependency.

What ships today:

- A full plant taxonomy: family, genus, species, and cultivar, with typed cultivation attributes covering life cycle, sun and water needs, soil pH, spacing, germination temperatures and days, sowing method and depth, frost tolerance, transplant timing, and days to maturity.
- Garden structure the way gardens are actually laid out: properties contain gardens, gardens contain growing areas and beds (raised, in-ground, or container), all tracked as graph containment so every bed knows where it lives.
- Plantings, the working heart of the graph: an actual crop in an actual bed, tied to its cultivar (or species when the cultivar is unknown), with a small planned-to-finished lifecycle, in-place transplant handling, and lineage back to the seed lot or starter batch it came from.
- Seed lots and starter batches with propagation lineage, so a plant in the ground traces back to the packet it started as.
- Pests, beneficials, and diseases as first-class entities: host relationships, parasitism and predation, pathogens, disease vectors, and cultivar resistance, all typed edges in the graph.
- Plant-to-plant claims (companions, antagonists, rotation warnings) that require provenance. Unsourced folklore doesn't get in.
- A bundled offline knowledge snapshot: 32 common crops with metric cultivation profiles, over a thousand cultivars, and the major home-garden pests and diseases, imported deterministically from pinned, cited sources. See [knowledge/](knowledge/) for how it's built and attributed.

Bundled plant, pest, and disease imagery is sourced from Wikimedia Commons, iNaturalist, and Flickr under public domain, CC0, and CC BY licenses; per-image attribution and provenance live in [knowledge/ATTRIBUTION.md](knowledge/ATTRIBUTION.md).

In the app, that graph turns into:

- A Today screen with the date, local weather, and the garden tasks that are due or overdue.
- A garden view that walks property, garden, growing area, and bed, down to per-bed planting detail with what's growing now and what grew before.
- Plant pages for everything in the bundled catalog: browse, search, and per-plant detail with cultivation conditions, cultivars, threats, and identification imagery.
- Capture flows built for speed: add a planting, log an observation (with photos via file picker or drag and drop), record a harvest, add and complete tasks, and add seed lots, all reachable from where they belong plus a global Record menu, prefilled with the current date and your last-used bed and unit.

Under it all is one typed knowledge graph over SQLite ([GRDB](https://github.com/groue/GRDB.swift)): entities and relationships carry provenance and confidence, single-cardinality edges are enforced with partial unique indexes, and every schema change lands as a migration with preservation tests. The `CroftCore` package splits into `Domain`, `Persistence`, `Graph`, `Knowledge`, and feature modules under `Core/`.

## Screenshots

<img src=".github/assets/screenshot_today.png" alt="Today screen with weather and due garden tasks" width="100%">
<img src=".github/assets/screenshot_garden.png" alt="Garden view with beds and plantings" width="100%">
<img src=".github/assets/screenshot_plant_page.png" alt="Plant page with cultivation detail and imagery" width="100%">
<img src=".github/assets/screenshot_capture.png" alt="Capture sheet recording a harvest" width="100%">

## Requirements

- macOS with Xcode 26 or later
- [mise](https://mise.jdx.dev)

## Build and run

```
mise install
mise run generate
open Croft.xcodeproj
```

The Xcode project is generated from `project.yml` with XcodeGen and is not checked in. Regenerate it after changing `project.yml`. The macOS app target is `Croft-macOS`; `mise run build` also rebuilds the bundled knowledge snapshot.

## Verify

```
mise run check
```

Runs formatting, lint, and the package tests on macOS. `mise run ci` adds the macOS app build and the runtime design-token resolution tests, and is what CI runs.

## License

MIT. See [LICENSE](LICENSE).
