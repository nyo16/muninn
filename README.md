<p align="center">
  <img src="images/header.png" alt="Muninn" width="800">
</p>

<p align="center">
  <strong>A fast, full-text search engine for Elixir, powered by <a href="https://github.com/quickwit-oss/tantivy">Tantivy</a></strong>
</p>

<p align="center">
  <a href="https://github.com/nyo16/muninn/actions/workflows/ci.yml"><img src="https://github.com/nyo16/muninn/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/nyo16/muninn/actions/workflows/release.yml"><img src="https://github.com/nyo16/muninn/actions/workflows/release.yml/badge.svg" alt="Precomp NIFs"></a>
  <a href="https://hex.pm/packages/muninn"><img src="https://img.shields.io/hexpm/v/muninn.svg" alt="Hex.pm"></a>
  <a href="https://hexdocs.pm/muninn"><img src="https://img.shields.io/badge/docs-hexdocs-blue.svg" alt="Docs"></a>
</p>

<p align="center">
  <em>Named after Odin's raven who gathers information from across the nine worlds.</em>
</p>

## Why "Muninn"?

In Norse mythology, Odin—the Allfather—possessed two ravens named **Huginn** (thought) and **Muninn** (memory). Each dawn, they would fly across the Nine Realms, observing everything that transpired in the world. At dusk, they returned to perch upon Odin's shoulders and whisper all they had learned into his ears.

Of the two, Odin feared more for Muninn:

> *"Huginn and Muninn fly each day*
> *over the spacious earth.*
> *I fear for Huginn, that he come not back,*
> *yet more anxious am I for Muninn."*
> — Grímnismál, Poetic Edda

Memory, after all, is what transforms raw observation into wisdom.

This library embodies that spirit: it flies through your documents, indexes what it finds, and returns with perfect recall—no matter how vast your data grows. Fast, reliable, and always remembering.

## Features

- **Fast**: Rust-powered search via native NIFs
- **Full-text search**: Text indexing with customizable tokenization
- **Multiple field types**: text, u64, i64, f64, bool, bytes
- **Custom tokenizers**: Per-field tokenizer support (`default`, `raw`, `en_stem`, `whitespace`)
- **Flexible schemas**: Define stored, indexed, and fast fields
- **Advanced queries**: Field-specific search, boolean operators, phrase matching, range queries, regex
- **Range queries**: Numeric range filtering with flexible boundaries
- **Fuzzy matching**: Error-tolerant search with Levenshtein distance for handling typos
- **MoreLikeThis**: Find similar documents by term distribution
- **Aggregations**: Terms, range, histogram buckets + avg, sum, stats, cardinality metrics with nesting
- **Sort by field**: Order results by fast field value instead of relevance score
- **Count queries**: Lightweight document counting without retrieval
- **Highlighting**: HTML snippets with highlighted matching words
- **Autocomplete**: Prefix search for typeahead functionality (with fuzzy support)
- **Thread-safe**: Concurrent index operations supported
- **Production-ready**: Comprehensive error handling and 229+ tests

## Installation

Add `muninn` to your `mix.exs`:

```elixir
def deps do
  [
    {:muninn, "~> 0.4.0"}
  ]
end
```

**Requirements:**
- Elixir ~> 1.18
- Rust ~> 1.92 (for compilation, Tantivy 0.26 + Rustler 0.37.2 require Rust 1.91+)

## Quick Start

### 1. Define a Schema

```elixir
alias Muninn.Schema

schema = Schema.new()
  |> Schema.add_text_field("title", stored: true, indexed: true, tokenizer: "en_stem")
  |> Schema.add_text_field("body", stored: true, indexed: true)
  |> Schema.add_text_field("category", stored: true, tokenizer: "raw", fast: true)
  |> Schema.add_u64_field("views", stored: true, indexed: true, fast: true)
  |> Schema.add_f64_field("price", stored: true, fast: true)
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

### Regex Search

Search with regular expressions on text fields:

```elixir
# Programmatic regex query
{:ok, results} = Searcher.search_regex(searcher, "title", "elix.*", limit: 10)

# Also supported via query parser syntax
{:ok, results} = Searcher.search_query(searcher, "/elix.*/", ["title"])
```

### MoreLikeThis (Find Similar Documents)

Find documents similar to a reference document by analyzing term distributions:

```elixir
{:ok, results} = Searcher.search_more_like_this(
  searcher,
  %{"title" => "Elixir programming", "body" => "Functional programming with Elixir"},
  min_doc_freq: 1,
  min_term_freq: 1,
  max_query_terms: 25,
  limit: 5
)
```

### Count Queries

Efficiently count matching documents without retrieving them:

```elixir
{:ok, count} = Searcher.count(searcher, "elixir AND phoenix", ["title", "body"])
# Returns: {:ok, 42}
```

### Sort by Field Value

Sort results by a fast field instead of relevance score:

```elixir
# Sort by price ascending
{:ok, results} = Searcher.search_query_sorted(
  searcher,
  "category:electronics",
  ["title"],
  "price"
)

# Sort by views descending
{:ok, results} = Searcher.search_query_sorted(
  searcher,
  "*",
  ["title"],
  "views",
  reverse: true,
  limit: 20
)

# Results include sort_value instead of score:
# %{"sort_value" => 5000, "doc" => %{"title" => "Popular Item", ...}}
```

> **Note:** Sort fields must be numeric (u64, i64, f64) with `fast: true` in the schema.

### Aggregations

Compute analytics over search results using the aggregation framework:

```elixir
alias Muninn.Aggregation
alias Muninn.Aggregation.{Bucket, Metric}

# Simple metric aggregation
aggs = Aggregation.new()
  |> Aggregation.add("avg_price", Metric.avg("price"))
  |> Aggregation.add("price_stats", Metric.stats("price"))

{:ok, results} = Searcher.aggregate(searcher, "*", ["title"], aggs)
# results["avg_price"]["value"] => 381.66
# results["price_stats"] => %{"count" => 6, "min" => 15.0, "max" => 999.0, ...}

# Terms aggregation (group by category)
aggs = Aggregation.new()
  |> Aggregation.add("by_category", Bucket.terms("category", size: 10))

{:ok, results} = Searcher.aggregate(searcher, "*", ["title"], aggs)
# results["by_category"]["buckets"] => [
#   %{"key" => "electronics", "doc_count" => 3},
#   %{"key" => "clothing", "doc_count" => 2},
#   ...
# ]

# Nested aggregation (stats per category)
aggs = Aggregation.new()
  |> Aggregation.add("by_category",
    Bucket.terms("category", size: 10)
    |> Aggregation.sub("price_stats", Metric.stats("price"))
  )

# Range buckets
aggs = Aggregation.new()
  |> Aggregation.add("price_ranges",
    Bucket.range("price", [
      %{"to" => 50.0},
      %{"from" => 50.0, "to" => 500.0},
      %{"from" => 500.0}
    ])
  )

# Histogram
aggs = Aggregation.new()
  |> Aggregation.add("price_hist", Bucket.histogram("price", 100.0))

# Scoped to a query (only aggregate matching docs)
{:ok, results} = Searcher.aggregate(
  searcher,
  "category:electronics",
  ["title", "category"],
  aggs
)
```

> **Note:** Aggregated fields must have `fast: true` in the schema. For text field aggregation (e.g., terms), use `tokenizer: "raw"` with `fast: true`.

**Available Bucket Aggregations:** `Bucket.terms/2`, `Bucket.range/2`, `Bucket.histogram/3`, `Bucket.filter/1`

**Available Metric Aggregations:** `Metric.avg/1`, `Metric.sum/1`, `Metric.min/1`, `Metric.max/1`, `Metric.stats/1`, `Metric.count/1`, `Metric.cardinality/2`, `Metric.percentiles/2`

## Field Types

| Type | Description | Example Use Case |
|------|-------------|------------------|
| `text` | Full-text searchable strings | Titles, descriptions, content |
| `u64` | Unsigned 64-bit integers | Counts, IDs, timestamps |
| `i64` | Signed 64-bit integers | Scores, offsets, differences |
| `f64` | 64-bit floating point | Prices, ratings, coordinates |
| `bool` | Boolean values | Flags, states (published, active) |
| `bytes` | Arbitrary binary data | Embeddings, serialized data, hashes |

**Field Options:**
- `stored: true/false` - Store the original value (retrievable in search results)
- `indexed: true/false` - Index the field for searching/filtering
- `fast: true/false` - Enable columnar storage (required for sorting and aggregations)
- `tokenizer: "name"` - Tokenizer for text fields: `"default"`, `"raw"`, `"en_stem"`, `"whitespace"`

**Defaults:** `stored: false`, `indexed: true`, `fast: false`, `tokenizer: nil` (uses `"default"`)

## Examples

See the `examples/` directory for complete working examples:

- `search_demo.exs` - Basic term search demonstration
- `advanced_search_demo.exs` - Query parser with boolean operators
- `highlighting_demo.exs` - Highlighted snippets and prefix search
- `range_functions_demo.exs` - Range queries (QueryParser vs dedicated functions)
- `fuzzy_search_demo.exs` - Fuzzy matching for typo tolerance
- `aggregation_demo.exs` - Aggregations, sorting, and analytics
- `complete_search_demo.exs` - Full feature showcase
- `comparison_demo.exs` - Side-by-side comparison of search methods

Run any example:
```bash
mix run examples/complete_search_demo.exs
```

## API Reference

### Core Modules

- `Muninn.Schema` - Define index schema with field types and options
- `Muninn.Index` - Create and open indices
- `Muninn.IndexWriter` - Add, update documents, commit/rollback
- `Muninn.IndexReader` - Read access to index
- `Muninn.Searcher` - Execute search queries, sorting, counting, and aggregations
- `Muninn.Query` - Build search queries
- `Muninn.Aggregation` - Builder DSL for aggregation requests
- `Muninn.Aggregation.Bucket` - Bucket aggregation builders (terms, range, histogram, filter)
- `Muninn.Aggregation.Metric` - Metric aggregation builders (avg, sum, min, max, stats, etc.)

### Search Methods

| Method | Description |
|--------|-------------|
| `Searcher.search/3` | Term query — direct term matching |
| `Searcher.search_query/4` | Query parser — boolean operators, phrase queries, field-specific |
| `Searcher.search_with_snippets/5` | Query parser + highlighted HTML snippets |
| `Searcher.search_prefix/4` | Prefix matching for autocomplete |
| `Searcher.search_range_u64/5` | Numeric range query (u64) |
| `Searcher.search_range_i64/5` | Numeric range query (i64) |
| `Searcher.search_range_f64/5` | Numeric range query (f64) |
| `Searcher.search_fuzzy/4` | Fuzzy matching with Levenshtein distance |
| `Searcher.search_fuzzy_prefix/4` | Fuzzy prefix matching for autocomplete with typo tolerance |
| `Searcher.search_fuzzy_with_snippets/5` | Fuzzy matching + highlighted snippets |
| `Searcher.search_regex/4` | Regex pattern matching on text fields |
| `Searcher.search_more_like_this/3` | Find similar documents by term distribution |
| `Searcher.search_query_sorted/5` | Query with results sorted by fast field value |
| `Searcher.count/3` | Count matching documents without retrieval |
| `Searcher.aggregate/5` | Execute aggregations over matching documents |

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

**Test Coverage:** 229+ tests covering:
- Schema and index operations (including bytes field, custom tokenizers, fast fields)
- Document CRUD operations
- All query types (term, boolean, phrase, prefix, range, fuzzy, regex, MoreLikeThis)
- Fuzzy search with distance levels (0-2), transposition handling
- Range queries with different numeric types and boundary options
- Sort by field value (ascending/descending)
- Count queries
- Aggregations (terms, range, histogram, stats, nested)
- Snippet generation and highlighting
- Concurrent operations
- Edge cases and error handling

## Documentation

Generate documentation:

```bash
mix docs
```

View at `doc/index.html`


## Development Status

**Current:** Phase 8 Complete - Tantivy 0.26.0 Features

**Implemented:**
- Schema definition and validation
- Index creation and management
- Document indexing with batch operations
- Basic term search
- Advanced query parser (field:value, AND/OR, phrases, ranges, regex)
- Range queries for all numeric types (u64, i64, f64)
- Fuzzy search with Levenshtein distance (fuzzy, fuzzy_prefix, fuzzy_with_snippets)
- Highlighted snippets for search results
- Prefix search for autocomplete
- Regex search on text fields
- MoreLikeThis (find similar documents)
- Count queries (lightweight document counting)
- Sort by fast field value (ascending/descending)
- Aggregations (terms, range, histogram, filter buckets + all metric types)
- Custom tokenizers (default, raw, en_stem, whitespace)
- Bytes field type for binary data
- Fast fields for columnar storage
- Transaction support (commit/rollback)
- Upgraded to Tantivy 0.26.0 (crates.io)

**Roadmap:**
- QueryParser integration for fuzzy syntax (`term~N`)
- Advanced suggestions system ("did you mean?")
- Document deletion and updates
- Date field type
- Custom scoring and boosting

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.

## Credits

- Built with [Rustler](https://github.com/rusterlium/rustler)
- Powered by [Tantivy](https://github.com/quickwit-oss/tantivy)
- Inspired by [tantivy_ex](https://github.com/alexiob/tantivy_ex)
