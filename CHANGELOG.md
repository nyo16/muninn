# Changelog

All notable changes to this project will be documented in this file.

## [0.4.0] - 2025-11-27

### Added
- Precompiled NIF binaries for all major platforms
- RustlerPrecompiled support for faster installation
- CI/CD workflows for automated releases
- Range query support (u64, i64, f64) with QueryParser syntax
- Fuzzy search with Levenshtein distance for typo tolerance
- Fuzzy prefix search for autocomplete with typo tolerance
- Highlighted snippets for fuzzy search results

### Changed
- Upgraded to Tantivy 0.25 (requires Rust 1.85+)
- License updated to Apache 2.0

## [0.3.0] - 2025-11-15

### Added
- Range queries with flexible boundary control
- QueryParser range syntax: `field:[low TO high]`
- Open-ended ranges with wildcards: `field:[1000 TO *]`

## [0.2.0] - 2025-11-10

### Added
- Advanced query parser with boolean operators (AND, OR)
- Phrase queries with exact matching
- Field-specific search syntax
- Highlighted snippets for search results
- Prefix search for autocomplete functionality

## [0.1.0] - 2025-11-01

### Added
- Initial release
- Schema definition with text, u64, i64, f64, bool field types
- Index creation and management
- Document indexing with batch operations
- Basic term search
- Transaction support (commit/rollback)
