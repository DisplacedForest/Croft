<img src=".github/assets/readme_header.png" alt="Croft: organize, plan, grow with purpose" width="100%">

Open-source, local-first garden operating system built on a horticultural knowledge graph. Native Swift and SwiftUI for macOS.

## Requirements

- macOS with Xcode 26 or later
- [mise](https://mise.jdx.dev)

## Build and run

```
mise install
mise run generate
open Croft.xcodeproj
```

The Xcode project is generated from `project.yml` with XcodeGen and is not checked in. Regenerate it after changing `project.yml`.

Shared code lives in the `CroftCore` package under `Core/`, with the `Domain`, `Persistence`, `Graph`, and `Knowledge` modules. The macOS app target is `Croft-macOS`.

## Verify

```
mise run check
```

Runs formatting, lint, and the package tests on macOS. `mise run ci` adds the macOS app build and the runtime design-token resolution tests, and is what CI runs.

## License

MIT. See [LICENSE](LICENSE).
