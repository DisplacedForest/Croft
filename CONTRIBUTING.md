# Contributing

## Setup

1. Install Xcode 26 or later.
2. Install [mise](https://mise.jdx.dev), then from the repository root:

```
mise install
lefthook install
mise run generate
```

`mise install` provides xcodegen, swiftlint, lefthook, and semgrep at pinned versions. `lefthook install` wires the git hooks: lint at pre-commit, `mise run check` at pre-push.

## Verification

```
mise run check
```

Formats with swift-format, lints with swift-format and SwiftLint, and runs the package test suite on macOS. Run it green before pushing. CI runs `mise run ci`, which adds the macOS app build. The iOS simulator tests, UI tests, and iOS build stay available on demand as `mise run test-ios`, `mise run test-ui`, `mise run test-all`, and `mise run build-ios`; they rejoin the default pipeline when an iOS release is on deck.

## Changes

Use a dedicated branch and pull request. Keep changes focused, review the diff,
and merge only after required GitHub Actions checks pass.

Changes are rejected when they fail `mise run ci`, include unrelated work, add
code comments, or leave documentation stale.
