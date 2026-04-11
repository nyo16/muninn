# Changelog

All notable changes to this project will be documented in this file.

## [0.5.4] - 2026-04-11

### Changed
- Switched Tantivy dependency from git (commit 51f340f) to crates.io release 0.26.0
  - No longer pinned to a specific commit; uses the official published release

### Tantivy 0.26.0 Highlights (since previous git pin)
- **Bugfixes**: Fixed phrase query prefixed with `*`, vint buffer overflow during index creation, integer overflow in `ExpUnrolledLinkedList` for large datasets, integer overflow in segment sorting and merge policy truncation, merging of intermediate aggregation results, deduplicate doc counts in term aggregation for multi-valued fields, lenient elastic range queries with trailing closing parentheses
- **Features**: Filter aggregation, composite aggregation, include/exclude filtering for term aggregations, regex support in query parser, TermQuery fallback for non-indexed fast fields, fast field support for Bytes values, natural-order-with-none-highest in TopDocs ordering, stemming behind feature flag
- **Performance**: High cardinality aggregation speed improvements, saturated posting list optimization, lazy scorers, union performance improvements, seek_danger for efficient intersections

## [0.5.3] - 2026-02-16

### Changed
- Updated Tantivy to latest main branch (commit 51f340f)
  - Replaced HyperLogLogPlus with Apache DataSketches HLL for improved cardinality estimation
  - Fixed intersection optimization bug in seek_into_the_danger_zone()
  - Fixed union performance regression
  - Aggregation collector refactoring (one per request instead of one per bucket)
  - Updated dependencies: lru 0.16.3, lz4_flex 0.12, hashbrown 0.16.1

## [0.5.2] - 2025-12-31

### Fixed
- Updated macOS runners for precompiled NIF builds (GitHub retired all macos-13 variants)
  - aarch64-apple-darwin (Apple Silicon): macos-14
  - x86_64-apple-darwin (Intel): macos-15-intel

## [0.5.1] - 2025-12-31

### Fixed
- Updated CI workflow to use Rust 1.92.0 (was 1.85.0)
- Updated release workflow to explicitly use Rust 1.92.0 for precompiled binaries

## [0.5.0] - 2025-12-31

### Changed
- Upgraded to Tantivy 0.26.0 from git main branch (commit b11605f)
- Updated Rust requirement to 1.92+ (rustler 0.37.2 requires Rust 1.91+)
- Updated rustler to 0.37.2
- Updated all Rust dependencies to latest compatible versions
- Fixed TopDocs API usage for Tantivy 0.26.0 compatibility (added `.order_by_score()`)

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
