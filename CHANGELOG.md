# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- SQLite persistence foundation: versioned forward-only migrations, foreign
  key enforcement, and a migration test harness that proves user data
  survives schema changes.

### Fixed

- Opening the app database now refuses to adopt a foreign SQLite file:
  a file that is not empty and not stamped as a Croft database fails with
  a typed error and is left untouched.
