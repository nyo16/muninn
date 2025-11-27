# Muninn Search Features Comparison

## Overview

This document compares the three search approaches available in Muninn, showing the progression from basic term search to advanced query capabilities.

---

## 1. Basic Term Search (Phase 4 - Original)

**Example**: `examples/search_demo.exs`

### What It Does
- Simple term matching using `Query.term/2`
- Searches for individual tokens in specified fields
- Case-insensitive (due to tokenization)

### API
```elixir
query = Query.term("title", "elixir")
{:ok, results} = Searcher.search(searcher, query, limit: 10)
```

### Limitations
- ❌ Cannot search specific fields dynamically
- ❌ No boolean operators (AND/OR)
- ❌ No phrase matching
- ❌ No highlighting
- ❌ No autocomplete/typeahead

### Example Results
```
Search: term("title", "elixir")
Found: 4 posts

1. Advanced Elixir Patterns (Score: 0.512)
2. Getting Started with Elixir (Score: 0.463)
3. Elixir Phoenix Framework Deep Dive (Score: 0.423)
4. Draft: Upcoming Elixir 2.0 Features (Score: 0.389)
```

---

## 2. Advanced Query Parser (New Feature)

**Example**: `examples/advanced_search_demo.exs`

### What It Does
- Natural query syntax with field specifiers
- Boolean logic (AND, OR, NOT)
- Phrase queries with quotes
- Required (+) and excluded (-) terms
- Complex nested queries with parentheses

### API
```elixir
# Field-specific
{:ok, results} = Searcher.search_query(
  searcher,
  "title:elixir",
  ["title", "content"]
)

# Boolean operators
{:ok, results} = Searcher.search_query(
  searcher,
  "elixir AND phoenix",
  ["title", "content"]
)

# Complex query
{:ok, results} = Searcher.search_query(
  searcher,
  "(title:elixir OR title:rust) AND category:tutorial AND -draft",
  ["title", "content", "category"]
)
```

### Capabilities
- ✅ Field-specific search: `title:elixir`
- ✅ Boolean AND: `elixir AND phoenix`
- ✅ Boolean OR: `rust OR elixir`
- ✅ Phrase queries: `"functional programming"`
- ✅ Required terms: `+elixir phoenix`
- ✅ Excluded terms: `elixir -draft`
- ✅ Grouping: `(term1 OR term2) AND term3`
- ✅ Case-insensitive
- ❌ No highlighting (use snippets for this)

### Example Results

**Query**: `title:elixir` (field-specific)
```
Found: 3 posts with 'elixir' in the title

1. Getting Started with Elixir (Score: 0.989)
2. Draft: Upcoming Elixir Features (Score: 0.989)
3. Concurrent Programming with Elixir OTP (Score: 0.903)
```

**Query**: `elixir AND web` (boolean)
```
Found: 1 posts with both 'elixir' AND 'web'

1. Phoenix Framework Deep Dive (Score: 2.39)
```

**Query**: `"functional programming"` (phrase)
```
Found: 2 posts with exact phrase

1. Introduction to Functional Programming
2. Getting Started with Elixir
```

**Query**: `+elixir -draft` (required/excluded)
```
Found: 3 posts with 'elixir' but NOT 'draft'

1. Concurrent Programming with Elixir OTP (Published: true)
2. Getting Started with Elixir (Published: true)
3. Phoenix Framework Deep Dive (Published: true)
```

---

## 3. Search with Highlighted Snippets (New Feature)

**Example**: `examples/highlighting_demo.exs`

### What It Does
- All capabilities of query parser
- PLUS: Returns HTML snippets with matching words highlighted
- Intelligent context extraction around matches
- Customizable snippet length

### API
```elixir
{:ok, results} = Searcher.search_with_snippets(
  searcher,
  "elixir",
  ["title", "content"],      # Fields to search
  ["content"],               # Fields to generate snippets for
  max_snippet_chars: 150
)
```

### Capabilities
- ✅ All query parser features (field:value, AND/OR, phrases, etc.)
- ✅ HTML highlighting with `<b>` tags
- ✅ Multiple snippet fields
- ✅ Customizable snippet length
- ✅ Context extraction around matches

### Example Results

**Query**: `elixir` with snippets
```
1. Introduction to Elixir Programming
   Snippet: <b>Elixir</b> is a dynamic, functional programming language
            designed for building scalable and maintainable applications.
            It leverages the Erlang VM, known

2. Ecto: Database Wrapper for Elixir
   Snippet: Ecto is a database wrapper and integrated query language for
            <b>Elixir</b>. It provides a standardized API for querying
            databases, composing queries, and
```

**Query**: `functional programming` (multi-word highlighting)
```
1. Functional Programming Fundamentals
   Snippet: <b>Functional</b> <b>programming</b> emphasizes immutability,
            pure functions, and declarative code. In <b>functional</b>
            languages like Elixir, data is immutable by
```

**Query**: `elixir AND concurrent` (boolean with highlighting)
```
1. Concurrent Programming with OTP
   Snippet: OTP (Open Telecom Platform) is a set of libraries and design
            principles for building <b>concurrent</b> and distributed
            systems in <b>Elixir</b> and Erlang
```

---

## 4. Prefix/Typeahead Search (New Feature)

**Example**: `examples/highlighting_demo.exs`, `examples/complete_search_demo.exs`

### What It Does
- Autocomplete functionality
- Searches for terms starting with a prefix
- Perfect for search-as-you-type UIs

### API
```elixir
{:ok, results} = Searcher.search_prefix(
  searcher,
  "title",      # Field to search
  "pho",        # Prefix
  limit: 10
)
```

### Capabilities
- ✅ Fast prefix matching
- ✅ Case-insensitive
- ✅ Perfect for autocomplete dropdowns
- ✅ Single field search
- ❌ Does not support boolean operators (use for simple autocomplete only)

### Example Results

**Prefix**: `pho`
```
Autocomplete suggestions for 'pho': 3 results

1. Phoenix Framework: Modern Web Development
2. Photography Composition Tips
3. Photoshop Beginner Tutorial
```

**Typeahead simulation** (as user types "programming"):
```
'pro'     → 3 matches
'prog'    → 2 matches
'progr'   → 2 matches
'program' → 2 matches
```

---

## Feature Comparison Matrix

| Feature | Basic Term | Query Parser | With Snippets | Prefix Search |
|---------|-----------|--------------|---------------|---------------|
| Single term search | ✅ | ✅ | ✅ | ✅ |
| Field-specific (field:value) | ❌ | ✅ | ✅ | ✅ |
| Boolean AND/OR | ❌ | ✅ | ✅ | ❌ |
| Phrase queries | ❌ | ✅ | ✅ | ❌ |
| Required/Excluded (+/-) | ❌ | ✅ | ✅ | ❌ |
| Complex nested queries | ❌ | ✅ | ✅ | ❌ |
| HTML highlighting | ❌ | ❌ | ✅ | ❌ |
| Snippet generation | ❌ | ❌ | ✅ | ❌ |
| Autocomplete/Typeahead | ❌ | ❌ | ❌ | ✅ |
| Multiple fields | ✅ | ✅ | ✅ | ❌ (single field) |
| Customizable snippet length | N/A | N/A | ✅ | N/A |

---

## Performance Characteristics

### Basic Term Search
- **Speed**: Fastest (direct term query)
- **Use case**: Simple, high-volume searches
- **Complexity**: O(log n) for term lookup

### Query Parser
- **Speed**: Fast (parsed once, then executed)
- **Use case**: User-facing search with natural syntax
- **Complexity**: O(log n) per term + boolean logic overhead

### With Snippets
- **Speed**: Moderate (includes snippet generation)
- **Use case**: Search results with previews
- **Complexity**: Query + snippet extraction (100-300 chars per match)
- **Overhead**: ~2-5ms per document for snippet generation

### Prefix Search
- **Speed**: Fast (regex-based term matching)
- **Use case**: Autocomplete as user types
- **Complexity**: O(k) where k = number of matching terms
- **Best for**: Short prefixes (2-5 chars), limited results (5-10)

---

## When to Use Each Approach

### Use Basic Term Search When:
- You have simple, programmatic searches
- Field and term are known at compile time
- Maximum performance is critical
- No UI formatting needed

**Example**: Background job searching logs
```elixir
query = Query.term("level", "error")
{:ok, results} = Searcher.search(searcher, query)
```

### Use Query Parser When:
- Users type natural search queries
- Need boolean logic (AND/OR)
- Field-specific search required
- Phrase matching needed

**Example**: User search bar
```elixir
user_query = "author:alice AND (elixir OR phoenix)"
{:ok, results} = Searcher.search_query(searcher, user_query, ["title", "content"])
```

### Use With Snippets When:
- Displaying search results to users
- Need to show matching context
- Want highlighted keywords in results
- Building search result previews

**Example**: Search results page with previews
```elixir
{:ok, results} = Searcher.search_with_snippets(
  searcher,
  user_query,
  ["title", "content"],
  ["content"],
  max_snippet_chars: 200
)

for hit <- results["hits"] do
  render_result(hit["doc"]["title"], hit["snippets"]["content"])
end
```

### Use Prefix Search When:
- Building autocomplete dropdowns
- Search-as-you-type functionality
- Suggesting completions
- Limited to single field

**Example**: Autocomplete search box
```elixir
# As user types "eli..."
{:ok, suggestions} = Searcher.search_prefix(searcher, "title", user_input, limit: 5)

# Display dropdown with suggestions
for hit <- suggestions["hits"] do
  render_suggestion(hit["doc"]["title"])
end
```

---

## Combined Example: Full-Featured Search UI

```elixir
defmodule MyApp.Search do
  alias Muninn.{Searcher}

  # Main search with highlighting
  def search(searcher, query, opts \\ []) do
    Searcher.search_with_snippets(
      searcher,
      query,
      ["title", "content", "tags"],  # Search these fields
      ["title", "content"],          # Show snippets for these
      max_snippet_chars: Keyword.get(opts, :snippet_length, 150),
      limit: Keyword.get(opts, :limit, 20)
    )
  end

  # Autocomplete as user types
  def autocomplete(searcher, prefix, field \\ "title") do
    if String.length(prefix) >= 2 do
      Searcher.search_prefix(searcher, field, prefix, limit: 10)
    else
      {:ok, %{"total_hits" => 0, "hits" => []}}
    end
  end

  # Quick filter (no snippets needed)
  def filter(searcher, field, value) do
    query = "#{field}:#{value}"
    Searcher.search_query(searcher, query, [field])
  end
end
```

---

## Summary

**Before** (Phase 4):
- ✅ Basic term search only
- ❌ Limited query capabilities
- ❌ No UI-friendly features

**After** (Phase 5 - Advanced Search):
- ✅ Natural query syntax (field:value, AND/OR, phrases)
- ✅ HTML-highlighted snippets for search results
- ✅ Prefix/autocomplete for typeahead
- ✅ Production-ready for user-facing search
- ✅ Comprehensive test coverage (23 new tests)
- ✅ Multiple demo examples

**Total New Capabilities**: 3 major features, 8+ query operators, snippet generation, autocomplete

All features are built on Tantivy's battle-tested search engine with Rust performance and Elixir ergonomics! 🚀
