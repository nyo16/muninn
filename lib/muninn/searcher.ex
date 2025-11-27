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
end
