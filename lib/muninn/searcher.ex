defmodule Muninn.Searcher do
  @moduledoc """
  Searcher executes queries against an index and returns results.

  The Searcher is obtained from an IndexReader and provides the main
  search functionality. It executes queries and returns ranked results.

  ## Usage

      {:ok, index} = Muninn.Index.open("/path/to/index")
      {:ok, reader} = Muninn.IndexReader.new(index)
      {:ok, searcher} = Muninn.Searcher.new(reader)

      # Execute a search
      query = Muninn.Query.term("title", "elixir")
      {:ok, results} = Muninn.Searcher.search(searcher, query, limit: 10)

  ## Search Results

  Results are returned as a `Muninn.SearchResult` struct containing:
  - `total_hits`: The number of matching documents
  - `hits`: A list of `Muninn.SearchHit` structs, each with:
    - `score`: Relevance score (higher is better)
    - `doc`: Map of stored field values

  Only fields marked as `stored: true` in the schema will be included
  in the returned documents.

  """

  alias Muninn.Native
  alias Muninn.Query

  @type t :: reference()

  @doc """
  Creates a new Searcher from an IndexReader.

  ## Parameters

    * `reader` - The IndexReader to create a searcher from

  ## Returns

    * `{:ok, searcher}` - Successfully created searcher
    * `{:error, reason}` - Failed to create searcher

  ## Examples

      {:ok, reader} = Muninn.IndexReader.new(index)
      {:ok, searcher} = Muninn.Searcher.new(reader)

  """
  @spec new(reference()) :: {:ok, t()} | {:error, String.t()}
  def new(reader) do
    Native.searcher_new(reader)
  end

  @doc """
  Executes a search query and returns results.

  ## Parameters

    * `searcher` - The searcher to use
    * `query` - The query to execute (e.g., from `Muninn.Query.term/2`)
    * `opts` - Keyword list of options:
      - `:limit` - Maximum number of results to return (default: 10)

  ## Returns

    * `{:ok, results}` - Search results as a `Muninn.SearchResult` struct
    * `{:error, reason}` - Search failed

  ## Examples

      query = Muninn.Query.term("title", "elixir")
      {:ok, results} = Muninn.Searcher.search(searcher, query, limit: 20)

      IO.puts("Found \#{results.total_hits} matches")
      for hit <- results.hits do
        IO.puts("Score: \#{hit.score}, Title: \#{hit.doc["title"]}")
      end

  """
  @spec search(t(), Query.Term.t(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def search(searcher, %Query.Term{} = query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    Native.searcher_search_term(searcher, query, limit)
  end

  @doc """
  Executes a search using natural query syntax.

  This function uses Tantivy's QueryParser to support advanced query syntax:

  - **Field-specific search**: `title:elixir` or `author:alice`
  - **Boolean operators**: `elixir AND phoenix`, `rust OR go`
  - **Phrase queries**: `"exact phrase match"`
  - **Required terms**: `+elixir phoenix` (elixir is required)
  - **Excluded terms**: `elixir -draft` (exclude draft)
  - **Combining**: `title:elixir AND (content:phoenix OR content:otp)`

  ## Parameters

    * `searcher` - The searcher to use
    * `query_string` - The query string with natural syntax
    * `default_fields` - List of field names to search when no field is specified
    * `opts` - Keyword list of options:
      - `:limit` - Maximum number of results to return (default: 10)

  ## Returns

    * `{:ok, results}` - Search results with total_hits and hits
    * `{:error, reason}` - Search or parse failed

  > Note: `total_hits` is the number of hits returned in this response — capped by
  > `:limit` and equal to `length(results["hits"])`, not the total number of
  > matching documents. Use `count/3` for the full match count regardless of limit.

  ## Examples

      # Search for "elixir" in title and content fields
      {:ok, results} = Muninn.Searcher.search_query(
        searcher,
        "elixir",
        ["title", "content"],
        limit: 10
      )

      # Field-specific search
      {:ok, results} = Muninn.Searcher.search_query(
        searcher,
        "title:phoenix",
        ["title", "content"]
      )

      # Boolean query
      {:ok, results} = Muninn.Searcher.search_query(
        searcher,
        "elixir AND phoenix",
        ["title", "content"]
      )

      # Phrase query
      {:ok, results} = Muninn.Searcher.search_query(
        searcher,
        ~s("functional programming"),
        ["title", "content"]
      )

      # Complex query
      {:ok, results} = Muninn.Searcher.search_query(
        searcher,
        "title:elixir AND (content:web OR content:concurrent) -draft",
        ["title", "content"]
      )

  """
  @spec search_query(t(), String.t(), list(String.t()), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def search_query(searcher, query_string, default_fields, opts \\ [])
      when is_binary(query_string) and is_list(default_fields) do
    limit = Keyword.get(opts, :limit, 10)

    Native.searcher_search_query(searcher, query_string, default_fields, limit)
  end

  @doc """
  Executes a search with highlighted snippets showing matching words in context.

  This function performs the same search as `search_query/4` but also generates
  highlighted snippets for specified fields. Snippets show the matching words in
  their original context with HTML `<b>` tags around matched terms.

  ## Parameters

    * `searcher` - The searcher to use
    * `query_string` - The query string with natural syntax
    * `default_fields` - List of field names to search when no field is specified
    * `snippet_fields` - List of text fields to generate snippets for
    * `opts` - Keyword list of options:
      - `:limit` - Maximum number of results to return (default: 10)
      - `:max_snippet_chars` - Maximum characters per snippet (default: 150)

  ## Returns

    * `{:ok, results}` - Search results with snippets
    * `{:error, reason}` - Search or parse failed

  > Note: `total_hits` is the number of hits returned in this response — capped by
  > `:limit` and equal to `length(results["hits"])`, not the total number of
  > matching documents. Use `count/3` for the full match count regardless of limit.

  Result format includes an additional `"snippets"` map with HTML-highlighted snippets:

      %{
        "total_hits" => 5,
        "hits" => [
          %{
            "score" => 3.14,
            "doc" => %{"title" => "...", "content" => "..."},
            "snippets" => %{
              "content" => "Learn about <b>elixir</b> and <b>phoenix</b>...",
              "title" => "<b>Elixir</b> Tutorial..."
            }
          }
        ]
      }

  ## Examples

      # Search with content snippets
      {:ok, results} = Muninn.Searcher.search_with_snippets(
        searcher,
        "elixir phoenix",
        ["title", "content"],
        ["content"]
      )

      for hit <- results["hits"] do
        IO.puts("Title: \#{hit["doc"]["title"]}")
        IO.puts("Snippet: \#{hit["snippets"]["content"]}")
      end

      # Search with custom snippet length
      {:ok, results} = Muninn.Searcher.search_with_snippets(
        searcher,
        "functional programming",
        ["content"],
        ["content"],
        max_snippet_chars: 200
      )

      # Multiple snippet fields
      {:ok, results} = Muninn.Searcher.search_with_snippets(
        searcher,
        "elixir web",
        ["title", "content"],
        ["title", "content"]
      )

  """
  @spec search_with_snippets(t(), String.t(), list(String.t()), list(String.t()), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def search_with_snippets(
        searcher,
        query_string,
        default_fields,
        snippet_fields,
        opts \\ []
      )
      when is_binary(query_string) and is_list(default_fields) and is_list(snippet_fields) do
    limit = Keyword.get(opts, :limit, 10)
    max_snippet_chars = Keyword.get(opts, :max_snippet_chars, 150)

    Native.searcher_search_with_snippets(
      searcher,
      query_string,
      default_fields,
      snippet_fields,
      max_snippet_chars,
      limit
    )
  end

  @doc """
  Performs a prefix search for autocomplete/typeahead functionality.

  Searches for terms in a specific field that start with the given prefix.
  This is useful for implementing autocomplete dropdowns and typeahead search.

  ## Parameters

    * `searcher` - The searcher to use
    * `field_name` - The field name to search in (must be a text field)
    * `prefix` - The prefix string to search for
    * `opts` - Keyword list of options:
      - `:limit` - Maximum number of results to return (default: 10)

  ## Returns

    * `{:ok, results}` - Search results with total_hits and hits
    * `{:error, reason}` - Search failed

  > Note: `total_hits` is the number of hits returned in this response — capped by
  > `:limit` and equal to `length(results["hits"])`, not the total number of
  > matching documents. Use `count/3` for the full match count regardless of limit.

  ## Examples

      # Search for titles starting with "eli"
      {:ok, results} = Muninn.Searcher.search_prefix(
        searcher,
        "title",
        "eli",
        limit: 5
      )

      # Get all authors starting with "al"
      {:ok, results} = Muninn.Searcher.search_prefix(
        searcher,
        "author",
        "al"
      )

      # Autocomplete as user types
      user_input = "pho"  # User typing "phoenix"
      {:ok, suggestions} = Muninn.Searcher.search_prefix(
        searcher,
        "title",
        user_input,
        limit: 10
      )

      for hit <- suggestions["hits"] do
        IO.puts(hit["doc"]["title"])
      end

  """
  @spec search_prefix(t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def search_prefix(searcher, field_name, prefix, opts \\ [])
      when is_binary(field_name) and is_binary(prefix) do
    limit = Keyword.get(opts, :limit, 10)

    Native.searcher_search_prefix(searcher, field_name, prefix, limit)
  end

  @doc """
  Performs a range query on a u64 field.

  Searches for documents where the field value falls within the specified range.

  ## Parameters

    * `searcher` - The searcher to use
    * `field_name` - The u64 field name to search
    * `lower` - Lower bound value
    * `upper` - Upper bound value
    * `opts` - Keyword list of options:
      - `:limit` - Maximum number of results (default: 10)
      - `:inclusive` - Bound inclusivity (default: :both)
        - `:both` - Include both bounds [lower, upper]
        - `:lower` - Include lower only [lower, upper)
        - `:upper` - Include upper only (lower, upper]
        - `:neither` - Exclude both (lower, upper)

  ## Returns

    * `{:ok, results}` - Search results
    * `{:error, reason}` - Search failed

  ## Examples

      # Find products with 100-1000 views (inclusive)
      {:ok, results} = Searcher.search_range_u64(
        searcher,
        "views",
        100,
        1000,
        inclusive: :both
      )

      # Find items with price 10-99 (excluding 10 and 99)
      {:ok, results} = Searcher.search_range_u64(
        searcher,
        "price",
        10,
        99,
        inclusive: :neither
      )

  """
  @spec search_range_u64(t(), String.t(), non_neg_integer(), non_neg_integer(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def search_range_u64(searcher, field_name, lower, upper, opts \\ [])
      when is_binary(field_name) and is_integer(lower) and is_integer(upper) do
    limit = Keyword.get(opts, :limit, 10)
    inclusive = Keyword.get(opts, :inclusive, :both)

    {lower_inclusive, upper_inclusive} =
      case inclusive do
        :both -> {true, true}
        :lower -> {true, false}
        :upper -> {false, true}
        :neither -> {false, false}
      end

    Native.searcher_search_range_u64(
      searcher,
      field_name,
      lower,
      upper,
      lower_inclusive,
      upper_inclusive,
      limit
    )
  end

  @doc """
  Performs a range query on an i64 field.

  Searches for documents where the field value falls within the specified range.

  ## Parameters

    * `searcher` - The searcher to use
    * `field_name` - The i64 field name to search
    * `lower` - Lower bound value
    * `upper` - Upper bound value
    * `opts` - Keyword list of options (see `search_range_u64/5`)

  ## Examples

      # Find temperatures between -10 and 30 degrees
      {:ok, results} = Searcher.search_range_i64(
        searcher,
        "temperature",
        -10,
        30
      )

  """
  @spec search_range_i64(t(), String.t(), integer(), integer(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def search_range_i64(searcher, field_name, lower, upper, opts \\ [])
      when is_binary(field_name) and is_integer(lower) and is_integer(upper) do
    limit = Keyword.get(opts, :limit, 10)
    inclusive = Keyword.get(opts, :inclusive, :both)

    {lower_inclusive, upper_inclusive} =
      case inclusive do
        :both -> {true, true}
        :lower -> {true, false}
        :upper -> {false, true}
        :neither -> {false, false}
      end

    Native.searcher_search_range_i64(
      searcher,
      field_name,
      lower,
      upper,
      lower_inclusive,
      upper_inclusive,
      limit
    )
  end

  @doc """
  Performs a range query on an f64 field.

  Searches for documents where the field value falls within the specified range.

  ## Parameters

    * `searcher` - The searcher to use
    * `field_name` - The f64 field name to search
    * `lower` - Lower bound value
    * `upper` - Upper bound value
    * `opts` - Keyword list of options (see `search_range_u64/5`)

  ## Examples

      # Find products priced between $10.00 and $50.00
      {:ok, results} = Searcher.search_range_f64(
        searcher,
        "price",
        10.0,
        50.0
      )

      # Find ratings 4.0 and above (excluding exactly 5.0)
      {:ok, results} = Searcher.search_range_f64(
        searcher,
        "rating",
        4.0,
        5.0,
        inclusive: :lower
      )

  """
  @spec search_range_f64(t(), String.t(), float(), float(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def search_range_f64(searcher, field_name, lower, upper, opts \\ [])
      when is_binary(field_name) and is_float(lower) and is_float(upper) do
    limit = Keyword.get(opts, :limit, 10)
    inclusive = Keyword.get(opts, :inclusive, :both)

    {lower_inclusive, upper_inclusive} =
      case inclusive do
        :both -> {true, true}
        :lower -> {true, false}
        :upper -> {false, true}
        :neither -> {false, false}
      end

    Native.searcher_search_range_f64(
      searcher,
      field_name,
      lower,
      upper,
      lower_inclusive,
      upper_inclusive,
      limit
    )
  end

  @doc """
  Performs fuzzy search for terms within a specified Levenshtein distance.

  Fuzzy search is error-tolerant and matches documents containing similar terms,
  making it ideal for handling typos and spelling variations. For example, searching
  for "elixr" with distance=1 will match documents containing "elixir".

  ## Parameters

  - `searcher` - The searcher resource
  - `field_name` - Name of the text field to search in
  - `term` - The search term (may contain typos)
  - `opts` - Keyword list of options:
    - `:distance` - Maximum Levenshtein distance (0-2, default: 1)
      - 0 = exact match only
      - 1 = one character difference (recommended for most use cases)
      - 2 = two character differences (slower, use for suggestions)
    - `:transposition` - Count character swaps as single edit (default: true)
      - true = "elixer" → "elixir" counts as 1 edit
      - false = "elixer" → "elixir" counts as 2 edits (delete + insert)
    - `:limit` - Maximum number of results (default: 10)

  ## Returns

  - `{:ok, results}` - Map with "total_hits" and "hits" array
  - `{:error, reason}` - Error string if search fails

  ## Examples

      # Basic fuzzy search (handles common typos)
      {:ok, results} = Searcher.search_fuzzy(searcher, "title", "elixr", distance: 1)

      # More tolerant search (allows 2 character differences)
      {:ok, results} = Searcher.search_fuzzy(searcher, "content", "phoneix", distance: 2)

      # Exact transposition handling
      {:ok, results} = Searcher.search_fuzzy(
        searcher,
        "author",
        "progarmming",
        distance: 1,
        transposition: true
      )

      # Higher result limit
      {:ok, results} = Searcher.search_fuzzy(
        searcher,
        "title",
        "elixr",
        distance: 1,
        limit: 50
      )

  ## Performance Notes

  - Distance=1: ~2-10x slower than exact search (recommended default)
  - Distance=2: ~5-50x slower than exact search (use sparingly)
  - Transposition=true is slightly faster than false
  """
  @spec search_fuzzy(t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def search_fuzzy(searcher, field_name, term, opts \\ [])
      when is_binary(field_name) and is_binary(term) do
    distance = Keyword.get(opts, :distance, 1)
    transposition = Keyword.get(opts, :transposition, true)
    limit = Keyword.get(opts, :limit, 10)

    # Validate distance
    unless distance in 0..2 do
      {:error, "Distance must be between 0 and 2"}
    else
      Native.searcher_search_fuzzy(
        searcher,
        field_name,
        term,
        distance,
        transposition,
        limit
      )
    end
  end

  @doc """
  Performs fuzzy prefix search combining autocomplete with typo tolerance.

  Similar to `search_prefix/4` but allows for spelling errors in the prefix.
  Useful for search-as-you-type with error tolerance.

  ## Parameters

  - `searcher` - The searcher resource
  - `field_name` - Name of the text field to search in
  - `prefix` - The prefix to match (may contain typos)
  - `opts` - Same as `search_fuzzy/4` options

  ## Examples

      # Autocomplete with typo tolerance
      {:ok, results} = Searcher.search_fuzzy_prefix(
        searcher,
        "title",
        "pho",  # User typing "phoenix" but made a typo
        distance: 1,
        limit: 10
      )
  """
  @spec search_fuzzy_prefix(t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def search_fuzzy_prefix(searcher, field_name, prefix, opts \\ [])
      when is_binary(field_name) and is_binary(prefix) do
    distance = Keyword.get(opts, :distance, 1)
    transposition = Keyword.get(opts, :transposition, true)
    limit = Keyword.get(opts, :limit, 10)

    unless distance in 0..2 do
      {:error, "Distance must be between 0 and 2"}
    else
      Native.searcher_search_fuzzy_prefix(
        searcher,
        field_name,
        prefix,
        distance,
        transposition,
        limit
      )
    end
  end

  @doc """
  Performs fuzzy search with highlighted snippets showing matched terms.

  Combines `search_fuzzy/4` with snippet generation for displaying context
  around fuzzy matches.

  ## Parameters

  - `searcher` - The searcher resource
  - `field_name` - Name of the text field to search in
  - `term` - The search term (may contain typos)
  - `snippet_fields` - List of field names to generate snippets from
  - `opts` - Keyword list combining fuzzy and snippet options:
    - `:distance` - Maximum Levenshtein distance (0-2, default: 1)
    - `:transposition` - Count swaps as single edit (default: true)
    - `:max_snippet_chars` - Maximum snippet length (default: 150)
    - `:limit` - Maximum results (default: 10)

  ## Examples

      {:ok, results} = Searcher.search_fuzzy_with_snippets(
        searcher,
        "content",
        "elixr",
        ["content"],
        distance: 1,
        max_snippet_chars: 200,
        limit: 10
      )

      # Access snippets
      for hit <- results["hits"] do
        IO.puts(hit["snippets"]["content"])  # "Learn about <b>Elixir</b>..."
      end
  """
  @spec search_fuzzy_with_snippets(t(), String.t(), String.t(), [String.t()], keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def search_fuzzy_with_snippets(searcher, field_name, term, snippet_fields, opts \\ [])
      when is_binary(field_name) and is_binary(term) and is_list(snippet_fields) do
    distance = Keyword.get(opts, :distance, 1)
    transposition = Keyword.get(opts, :transposition, true)
    max_snippet_chars = Keyword.get(opts, :max_snippet_chars, 150)
    limit = Keyword.get(opts, :limit, 10)

    unless distance in 0..2 do
      {:error, "Distance must be between 0 and 2"}
    else
      Native.searcher_search_fuzzy_with_snippets(
        searcher,
        field_name,
        term,
        snippet_fields,
        distance,
        transposition,
        max_snippet_chars,
        limit
      )
    end
  end

  @doc """
  Counts documents matching a query without retrieving them.

  This is more efficient than a full search when you only need the count.

  ## Parameters

    * `searcher` - The searcher to use
    * `query_string` - The query string with natural syntax
    * `default_fields` - List of field names to search when no field is specified

  ## Examples

      {:ok, count} = Muninn.Searcher.count(searcher, "elixir", ["title", "content"])

  """
  @spec count(t(), String.t(), list(String.t())) ::
          {:ok, non_neg_integer()} | {:error, String.t()}
  def count(searcher, query_string, default_fields)
      when is_binary(query_string) and is_list(default_fields) do
    Native.searcher_count(searcher, query_string, default_fields)
  end

  @doc """
  Performs a regex search on a specific field.

  Uses Tantivy's regex engine (based on `tantivy-fst`). Note that regex patterns
  match against indexed (lowercased, tokenized) terms.

  The query parser also supports `/regex/` syntax via `search_query/4`.

  ## Parameters

    * `searcher` - The searcher to use
    * `field_name` - The text field to search in
    * `pattern` - The regex pattern
    * `opts` - Keyword list of options:
      - `:limit` - Maximum number of results (default: 10)

  ## Examples

      {:ok, results} = Muninn.Searcher.search_regex(searcher, "title", "elix.*")

  """
  @spec search_regex(t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def search_regex(searcher, field_name, pattern, opts \\ [])
      when is_binary(field_name) and is_binary(pattern) do
    limit = Keyword.get(opts, :limit, 10)
    Native.searcher_search_regex(searcher, field_name, pattern, limit)
  end

  @doc """
  Finds documents similar to the provided document fields.

  Uses Tantivy's MoreLikeThis query to find documents with similar term distributions.

  ## Parameters

    * `searcher` - The searcher to use
    * `document_fields` - A map of field name to text value representing the reference document
    * `opts` - Keyword list of options:
      - `:min_doc_freq` - Ignore terms appearing in fewer docs (default: 1)
      - `:min_term_freq` - Ignore terms less frequent than this (default: 1)
      - `:max_doc_freq` - Ignore terms in more docs than this (default: `:unlimited`)
      - `:min_word_length` - Minimum word length (default: 0, no minimum)
      - `:max_word_length` - Maximum word length (default: 0, no maximum)
      - `:max_query_terms` - Maximum terms in the generated query (default: 25)
      - `:boost_factor` - Score boost factor (default: 1.0)
      - `:limit` - Maximum results (default: 10)

  ## Examples

      {:ok, results} = Muninn.Searcher.search_more_like_this(
        searcher,
        %{"title" => "Elixir programming", "content" => "Functional programming with Elixir"},
        min_doc_freq: 1,
        min_term_freq: 1,
        limit: 5
      )

  """
  @spec search_more_like_this(t(), map(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def search_more_like_this(searcher, document_fields, opts \\ [])
      when is_map(document_fields) do
    min_doc_freq = Keyword.get(opts, :min_doc_freq, 1)
    min_term_freq = Keyword.get(opts, :min_term_freq, 1)

    max_doc_freq =
      case Keyword.get(opts, :max_doc_freq, :unlimited) do
        :unlimited -> 18_446_744_073_709_551_615
        val -> val
      end

    min_word_length = Keyword.get(opts, :min_word_length, 0)
    max_word_length = Keyword.get(opts, :max_word_length, 0)
    max_query_terms = Keyword.get(opts, :max_query_terms, 25)
    boost_factor = Keyword.get(opts, :boost_factor, 1.0)
    limit = Keyword.get(opts, :limit, 10)

    Native.searcher_search_more_like_this(
      searcher,
      document_fields,
      min_doc_freq,
      min_term_freq,
      max_doc_freq,
      min_word_length,
      max_word_length,
      max_query_terms,
      boost_factor,
      limit
    )
  end

  @doc """
  Executes a search sorted by a fast field value instead of relevance score.

  Requires the sort field to be a numeric type (u64, i64, f64) with `fast: true`
  in the schema.

  ## Parameters

    * `searcher` - The searcher to use
    * `query_string` - The query string with natural syntax
    * `default_fields` - List of field names to search when no field is specified
    * `sort_field` - Name of the fast field to sort by
    * `opts` - Keyword list of options:
      - `:reverse` - Sort descending when `true` (default: `false` for ascending)
      - `:limit` - Maximum number of results (default: 10)

  ## Returns

  Results include `"sort_value"` (the fast field value) instead of `"score"`.

  ## Examples

      {:ok, results} = Muninn.Searcher.search_query_sorted(
        searcher,
        "*",
        ["title"],
        "price",
        reverse: true,
        limit: 10
      )

  """
  @spec search_query_sorted(t(), String.t(), list(String.t()), String.t(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def search_query_sorted(searcher, query_string, default_fields, sort_field, opts \\ [])
      when is_binary(query_string) and is_list(default_fields) and is_binary(sort_field) do
    limit = Keyword.get(opts, :limit, 10)
    reverse = Keyword.get(opts, :reverse, false)

    Native.searcher_search_query_sorted(
      searcher,
      query_string,
      default_fields,
      sort_field,
      reverse,
      limit
    )
  end

  @doc """
  Executes aggregations over documents matching a query.

  Uses Tantivy's aggregation framework. Aggregated fields must have `fast: true`
  in the schema.

  ## Parameters

    * `searcher` - The searcher to use
    * `query_string` - Query to scope which documents are aggregated (use `"*"` for all)
    * `default_fields` - Default fields for the query parser
    * `aggregations` - Aggregation request as a map (from builder DSL) or JSON string
    * `opts` - Reserved for future options

  ## Examples

      aggs = %{
        "avg_price" => %{"avg" => %{"field" => "price"}}
      }

      {:ok, results} = Muninn.Searcher.aggregate(searcher, "*", ["title"], aggs)

  """
  @spec aggregate(t(), String.t(), list(String.t()), map() | String.t(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def aggregate(searcher, query_string, default_fields, aggregations, _opts \\ [])
      when is_binary(query_string) and is_list(default_fields) do
    aggs_json =
      case aggregations do
        json when is_binary(json) -> json
        map when is_map(map) -> Jason.encode!(map)
      end

    case Native.searcher_aggregate(searcher, query_string, default_fields, aggs_json) do
      {:ok, result_json} -> {:ok, Jason.decode!(result_json)}
      {:error, _} = error -> error
    end
  end
end
