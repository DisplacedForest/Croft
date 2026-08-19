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

Formats with swift-format, lints with swift-format and SwiftLint, runs the package test suite on macOS, and compiles the macOS app target, so module-level breaks that only app compilation catches fail before push. For tight iteration loops, `mise run check-fast` skips the app build and runs format, lint, and tests only; the pre-push gate remains the full `check`. CI runs `mise run ci`, which adds the runtime design-token resolution tests (`mise run test-runtime-tokens`), verifying every color token resolves from the compiled asset catalog. The iOS simulator tests, UI tests, and iOS build stay available on demand as `mise run test-ios`, `mise run test-ui`, `mise run test-all`, and `mise run build-ios`; they rejoin the default pipeline when an iOS release is on deck.

`Core/CroftCore/Package.resolved` pins the package-only graph and must match HEAD after any build; `mise run ci` fails if a resolver rewrote it. The app project's package graph (which adds Sparkle) is pinned by `project.resolved` at the repository root, which project generation copies into the generated workspace. The same guard fails if the two lockfiles disagree on GRDB, if `project.resolved` disagrees with `project.yml` on Sparkle, or if a build re-resolved the workspace pins away from `project.resolved`. Accidental drift gets discarded, never committed. For an intentional dependency update, change `Package.swift` or `project.yml` (and `Core/CroftCore/Package.resolved` if the package graph moved), run `mise run refresh-resolved`, and commit the regenerated `project.resolved` with it.

## Changes

Use a dedicated branch and pull request. Keep changes focused, review the diff,
and merge only after required GitHub Actions checks pass.

Changes are rejected when they fail `mise run ci`, include unrelated work, or
leave documentation stale.

## Changelog

User-facing changes get a line under the Unreleased heading in CHANGELOG.md
before the session ends; treat it as part of finishing the work. At release
time the maintainer curates that section, using `mise run changelog-draft` as
a safety net: it prints a skeleton grouped by Conventional Commit type from
the commits since the last version tag (or the repository root before the
first release), but never writes the file itself. Squash merges with
Conventional Commit subjects are what keep its output reliable. Releasing
renames Unreleased to the version and date.
