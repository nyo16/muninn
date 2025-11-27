defmodule Muninn.Query.Term do
  @moduledoc """
  Represents a term query for matching specific terms in a field.
  """

  @type t :: %__MODULE__{
          field: String.t(),
          value: String.t()
        }

  defstruct [:field, :value]
end

defmodule Muninn.Query do
  @moduledoc """
  Query construction for searching documents.

  This module provides functions to build different types of queries
  for searching the index.

  ## Query Types

  - **Term Query**: Matches documents containing a specific term in a field
  - More query types coming in future phases

  ## Examples

      # Simple term query
      query = Muninn.Query.term("title", "elixir")

      # Search with the query
      {:ok, results} = Muninn.Searcher.search(searcher, query, limit: 10)

  """

  alias Muninn.Query

  @doc """
  Creates a term query that matches documents containing a specific term.

  Term queries search for exact term matches in the specified field.
  For text fields, the term should match a single token after tokenization.

  ## Parameters

    * `field` - The field name to search in
    * `value` - The term value to search for

  ## Returns

  A term query struct.

  ## Examples

      # Search for "elixir" in the title field
      query = Muninn.Query.term("title", "elixir")

      # Search for a product by SKU
      query = Muninn.Query.term("sku", "PROD-123")

  """
  @spec term(String.t(), String.t()) :: Query.Term.t()
  def term(field, value) when is_binary(field) and is_binary(value) do
    %Query.Term{field: field, value: value}
  end
end
