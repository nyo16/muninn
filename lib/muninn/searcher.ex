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
end
