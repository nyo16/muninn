# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Muninn is a full-text search engine for Elixir powered by Tantivy (Rust). It uses Rustler to bridge Elixir and Rust via NIFs (Native Implemented Functions).

## Build & Development Commands

```bash
# Install dependencies (compiles Rust NIF automatically)
mix deps.get

# Run all tests
mix test

# Run a single test file
mix test test/muninn/searcher_test.exs

# Run a specific test by line number
mix test test/muninn/searcher_test.exs:42

# Run examples
mix run examples/complete_search_demo.exs

# Format code (both Elixir and Rust)
mix format
cargo fmt --manifest-path=native/muninn/Cargo.toml

# Lint Elixir code
mix credo

# Lint Rust code
cargo clippy --manifest-path=native/muninn/Cargo.toml -- -Dwarnings -A clippy::too_many_arguments -A clippy::needless_lifetimes

# Type checking
mix dialyzer

# Generate documentation
mix docs
```

## Architecture

```
lib/
├── muninn.ex              # Main module
├── muninn/
│   ├── native.ex          # NIF stubs (Rustler bridge)
│   ├── schema.ex          # Schema definition API
│   ├── schema/field.ex    # Field type definitions
│   ├── index.ex           # Index creation/management
│   ├── index_writer.ex    # Document indexing operations
│   ├── index_reader.ex    # Read access to index
│   ├── searcher.ex        # Search query execution
│   ├── query.ex           # Query building
│   └── search_result.ex   # Result structs

native/muninn/src/
├── lib.rs                 # NIF entry point, function registrations
├── schema.rs              # Schema building in Rust
├── index.rs               # Index operations
├── writer.rs              # Document writing
├── reader.rs              # Index reading
└── searcher.rs            # Search implementations
```

### Data Flow

1. **Elixir API** (`lib/muninn/*.ex`) - High-level functions users call
2. **Native Bridge** (`lib/muninn/native.ex`) - Rustler NIF stubs
3. **Rust NIFs** (`native/muninn/src/lib.rs`) - NIF entry points
4. **Rust Modules** (`native/muninn/src/*.rs`) - Tantivy operations
5. **Tantivy** - Underlying search engine

### Key Patterns

- **Resource Arcs**: Rust resources (Index, Reader, Searcher) are wrapped in `ResourceArc<T>` for thread-safe sharing with Elixir
- **DirtyIo Scheduling**: `writer_commit` uses `#[rustler::nif(schedule = "DirtyIo")]` for blocking I/O operations
- **Error Handling**: Rust returns `Result<T, String>`, Elixir wraps as `{:ok, result}` or `{:error, reason}`

## Requirements

- Elixir ~> 1.18
- Rust ~> 1.85 (Tantivy 0.25 requires Edition 2024)
- Tantivy 0.25

## Testing

175+ tests organized by module:
- `test/muninn/schema_test.exs` - Schema operations
- `test/muninn/index_test.exs` - Index creation
- `test/muninn/searcher_test.exs` - Search functionality
- `test/muninn/query_parser_test.exs` - Query syntax parsing
- `test/muninn/range_query_test.exs` - Range queries
- `test/muninn/fuzzy_search_test.exs` - Fuzzy matching
- `test/muninn/integration_test.exs` - End-to-end tests

## CI Notes

CI runs on self-hosted runners. The `MUNINN_BUILD=true` env var enables NIF compilation. Clippy allows `too_many_arguments` and `needless_lifetimes` warnings.
