# Muninn

A fast, full-text search engine for Elixir, powered by [Tantivy](https://github.com/quickwit-oss/tantivy) (Rust).

Named after Odin's raven who gathers information from across the nine worlds.

## Features

- **Fast**: Rust-powered search via native NIFs
- **Full-text search**: Text indexing with customizable tokenization
- **Multiple field types**: text, u64, i64, f64, bool
- **Flexible schemas**: Define stored and indexed fields
- **Advanced queries**: Field-specific search, boolean operators, phrase matching, range queries
- **Range queries**: Numeric range filtering with flexible boundaries
- **Fuzzy matching**: Error-tolerant search with Levenshtein distance for handling typos
- **Highlighting**: HTML snippets with highlighted matching words
- **Autocomplete**: Prefix search for typeahead functionality (with fuzzy support)
- **Thread-safe**: Concurrent index operations supported
- **Production-ready**: Comprehensive error handling and 175+ tests

## Installation

Add `muninn` to your `mix.exs`:

```elixir
def deps do
  [
    {:muninn, "~> 0.1.0"}
  ]
end
```

**Requirements:**
- Elixir ~> 1.18
- Rust ~> 1.85 (for compilation, Tantivy 0.25 requires Edition 2024)

## Quick Start

### 1. Define a Schema

```elixir
alias Muninn.Schema

schema = Schema.new()
  |> Schema.add_text_field("title", stored: true, indexed: true)
  |> Schema.add_text_field("body", stored: true, indexed: true)
  |> Schema.add_u64_field("views", stored: true, indexed: true)
  |> Schema.add_bool_field("published", stored: true, indexed: true)
```

### 2. Create and Index Documents

```elixir
alias Muninn.{Index, IndexWriter}

{:ok, index} = Index.create("/path/to/index", schema)

IndexWriter.add_document(index, %{
  "title" => "Getting Started with Elixir",
  "body" => "Elixir is a functional programming language...",
  "views" => 1523,
  "published" => true
})

IndexWriter.commit(index)
```

### 3. Search Documents

```elixir
alias Muninn.{IndexReader, Searcher}

{:ok, reader} = IndexReader.new(index)
{:ok, searcher} = Searcher.new(reader)

# Simple search
{:ok, results} = Searcher.search_query(
  searcher,
  "elixir programming",
  ["title", "body"]
)

# Field-specific search
{:ok, results} = Searcher.search_query(
  searcher,
  "title:elixir AND published:true",
  ["title", "body"]
)

# Search with highlighted snippets
{:ok, results} = Searcher.search_with_snippets(
  searcher,
  "functional programming",
  ["title", "body"],
  ["body"],
  max_snippet_chars: 150
)

# Autocomplete/prefix search
{:ok, results} = Searcher.search_prefix(
  searcher,
  "title",
  "eli",
  limit: 10
)

# Range queries
{:ok, results} = Searcher.search_query(
  searcher,
  "views:[1000 TO 5000]",
  ["title"]
)

# Programmatic range queries
{:ok, results} = Searcher.search_range_u64(
  searcher,
  "views",
  1000,
  5000,
  inclusive: :both
)

# Fuzzy search (handles typos)
{:ok, results} = Searcher.search_fuzzy(
  searcher,
  "title",
  "elixr",  # Typo for "elixir"
  distance: 1
)

# Fuzzy prefix (autocomplete with typo tolerance)
{:ok, results} = Searcher.search_fuzzy_prefix(
  searcher,
  "author",
  "jse",  # Typo while typing "jose"
  distance: 1,
  limit: 10
)
```

## Search Features

### Query Parser Syntax

- **Field-specific**: `title:elixir` searches only in title field
- **Boolean AND**: `elixir AND phoenix` requires both terms
- **Boolean OR**: `rust OR elixir` matches either term
- **Phrase queries**: `"functional programming"` exact phrase match
- **Required terms**: `+elixir phoenix` elixir is required, phoenix optional
- **Excluded terms**: `elixir -draft` include elixir, exclude draft
- **Grouping**: `(elixir OR rust) AND tutorial` complex nested queries
- **Range queries**: `views:[100 TO 1000]` numeric range (u64, i64, f64)
- **Open-ended ranges**: `price:[50.0 TO *]` unbounded upper limit
- **Case-insensitive**: All searches are case-insensitive

### Highlighted Snippets

Returns HTML snippets with matching words wrapped in `<b>` tags:

```elixir
{:ok, results} = Searcher.search_with_snippets(
  searcher,
  "elixir",
  ["title", "content"],
  ["content"],
  max_snippet_chars: 200
)

# Result contains:
# "snippets" => %{
#   "content" => "<b>Elixir</b> is a functional programming language..."
# }
```

### Prefix Search (Autocomplete)

Perfect for search-as-you-type functionality:

```elixir
{:ok, results} = Searcher.search_prefix(searcher, "title", "pho", limit: 10)
# Matches: "Phoenix Framework", "Photography", "Photoshop", etc.
```

### Range Queries

Filter numeric fields with flexible boundary control:

```elixir
# QueryParser syntax - inclusive range [100, 1000]
{:ok, results} = Searcher.search_query(searcher, "views:[100 TO 1000]", ["title"])

# Programmatic API with boundary control
{:ok, results} = Searcher.search_range_u64(
  searcher,
  "views",
  100,
  1000,
  inclusive: :both    # :both, :lower, :upper, :neither
)

# Range queries work for all numeric types
Searcher.search_range_u64(searcher, "views", 0, 1000)        # Unsigned integers
Searcher.search_range_i64(searcher, "temperature", -10, 30)  # Signed integers
Searcher.search_range_f64(searcher, "price", 9.99, 99.99)    # Floating point

# Combine with text search
{:ok, results} = Searcher.search_query(
  searcher,
  "title:elixir AND views:[1000 TO *]",
  ["title"]
)
```

### Fuzzy Search (Typo Tolerance)

Handle spelling errors and typos automatically using Levenshtein distance:

```elixir
# Basic fuzzy search (distance=1: one character difference)
{:ok, results} = Searcher.search_fuzzy(
  searcher,
  "title",
  "elixr",  # Typo for "elixir"
  distance: 1
)

# More tolerant search (distance=2: two character differences)
{:ok, results} = Searcher.search_fuzzy(
  searcher,
  "content",
  "phoneix",  # Typo for "phoenix"
  distance: 2
)

# Fuzzy prefix search (autocomplete with typo tolerance)
{:ok, results} = Searcher.search_fuzzy_prefix(
  searcher,
  "author",
  "jse",  # User typing "jose" with typo
  distance: 1,
  limit: 10
)

# Fuzzy search with highlighted snippets
{:ok, results} = Searcher.search_fuzzy_with_snippets(
  searcher,
  "content",
  "elixr",
  ["content"],
  distance: 1,
  max_snippet_chars: 150
)

# Transposition handling (character swaps count as 1 edit)
{:ok, results} = Searcher.search_fuzzy(
  searcher,
  "title",
  "elixer",  # "i" and "x" swapped
  distance: 1,
  transposition: true  # default
)
```

**Performance Notes:**
- **Distance=1**: ~2-10x slower than exact search (recommended for real-time)
- **Distance=2**: ~5-50x slower than exact search (use for suggestions only)
- Transposition cost enabled by default (more intuitive for users)

## Field Types

| Type | Description | Example Use Case |
|------|-------------|------------------|
| `text` | Full-text searchable strings | Titles, descriptions, content |
| `u64` | Unsigned 64-bit integers | Counts, IDs, timestamps |
| `i64` | Signed 64-bit integers | Scores, offsets, differences |
| `f64` | 64-bit floating point | Prices, ratings, coordinates |
| `bool` | Boolean values | Flags, states (published, active) |

**Field Options:**
- `stored: true/false` - Store the original value (retrievable in search results)
- `indexed: true/false` - Index the field for searching/filtering

**Defaults:** `stored: false`, `indexed: true`

## Examples

See the `examples/` directory for complete working examples:

- `search_demo.exs` - Basic term search demonstration
- `advanced_search_demo.exs` - Query parser with boolean operators
- `highlighting_demo.exs` - Highlighted snippets and prefix search
- `range_functions_demo.exs` - Range queries (QueryParser vs dedicated functions)
- `fuzzy_search_demo.exs` - Fuzzy matching for typo tolerance
- `complete_search_demo.exs` - Full feature showcase
- `comparison_demo.exs` - Side-by-side comparison of search methods

Run any example:
```bash
mix run examples/complete_search_demo.exs
```

## API Reference

### Core Modules

- `Muninn.Schema` - Define index schema with field types
- `Muninn.Index` - Create and open indices
- `Muninn.IndexWriter` - Add, update documents, commit/rollback
- `Muninn.IndexReader` - Read access to index
- `Muninn.Searcher` - Execute search queries
- `Muninn.Query` - Build search queries

### Search Methods

**Basic Term Search** - Simple, direct term matching:
```elixir
query = Query.term("field", "value")
Searcher.search(searcher, query, limit: 10)
```

**Query Parser** - Natural syntax with boolean operators:
```elixir
Searcher.search_query(searcher, "field:value AND other", ["field", "other"])
```

**With Snippets** - Highlighted search results:
```elixir
Searcher.search_with_snippets(searcher, query, search_fields, snippet_fields, opts)
```

**Prefix Search** - Autocomplete functionality:
```elixir
Searcher.search_prefix(searcher, "field", "prefix", limit: 10)
```

**Range Queries** - Numeric filtering with flexible boundaries:
```elixir
Searcher.search_range_u64(searcher, "views", 100, 1000, inclusive: :both)
Searcher.search_range_i64(searcher, "temperature", -10, 30)
Searcher.search_range_f64(searcher, "price", 10.0, 100.0)
```

**Fuzzy Search** - Error-tolerant matching with Levenshtein distance:
```elixir
Searcher.search_fuzzy(searcher, "title", "elixr", distance: 1)
Searcher.search_fuzzy_prefix(searcher, "author", "jse", distance: 1)
Searcher.search_fuzzy_with_snippets(searcher, "content", "elixr", ["content"])
```

## Architecture

```
Elixir Application
      ↓
  Muninn API (lib/)
      ↓
  Native NIFs (Rustler)
      ↓
  Tantivy (Rust)
```

- **Elixir layer**: High-level API, schema definition, validation
- **Rust layer**: Performance-critical operations, Tantivy bindings
- **Thread safety**: Arc<Mutex<>> wrappers ensure safe concurrent access

## Performance

- Index creation: ~20-25ms per index
- Query parsing: <0.1ms per query
- Term search: O(log n) for term lookup
- Fuzzy search (distance=1): ~2-10x slower than exact search
- Fuzzy search (distance=2): ~5-50x slower than exact search
- Snippet generation: ~2-5ms per document
- Concurrent operations: Fully supported
- Scales to millions of documents

## Testing

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/muninn/searcher_test.exs
```

**Test Coverage:** 175+ tests covering:
- Schema and index operations
- Document CRUD operations
- All query types (term, boolean, phrase, prefix, range, fuzzy)
- Fuzzy search with distance levels (0-2), transposition handling
- Range queries with different numeric types and boundary options
- Snippet generation and highlighting
- Concurrent operations
- Edge cases and error handling

## Documentation

Generate documentation:

```bash
mix docs
```

View at `doc/index.html`

For detailed feature comparison and use cases, see [SEARCH_FEATURES.md](SEARCH_FEATURES.md).

## Development Status

**Current:** Phase 7 Complete - Fuzzy Matching and Typo Tolerance

**Implemented:**
- Schema definition and validation
- Index creation and management
- Document indexing with batch operations
- Basic term search
- Advanced query parser (field:value, AND/OR, phrases, ranges)
- Range queries for all numeric types (u64, i64, f64)
- Fuzzy search with Levenshtein distance (3 functions: fuzzy, fuzzy_prefix, fuzzy_with_snippets)
- Highlighted snippets for search results
- Prefix search for autocomplete
- Transaction support (commit/rollback)
- Upgraded to Tantivy 0.25

**Roadmap:**
- QueryParser integration for fuzzy syntax (`term~N`)
- Advanced suggestions system ("did you mean?")
- Faceted search and aggregations
- Custom analyzers and tokenizers
- Sorting and custom scoring

## License

MIT

## Credits

- Built with [Rustler](https://github.com/rusterlium/rustler)
- Powered by [Tantivy](https://github.com/quickwit-oss/tantivy)
- Inspired by [tantivy_ex](https://github.com/alexiob/tantivy_ex)
