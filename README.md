# Croft

Open-source, local-first garden operating system built on a horticultural knowledge graph. Native Swift and SwiftUI for macOS and iOS.

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

Shared code lives in the `CroftCore` package under `Core/`, with the `Domain`, `Persistence`, `Graph`, and `Knowledge` modules. The app targets are `Croft-macOS` and `Croft-iOS`.

## Verify

```
mise run check
```

Runs formatting, lint, and the test suites for macOS and iOS. `mise run ci` adds full builds of both apps and is what CI runs.

## License

MIT. See [LICENSE](LICENSE).
