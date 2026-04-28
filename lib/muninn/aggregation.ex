defmodule Muninn.Aggregation do
  @moduledoc """
  Builder for constructing aggregation requests.

  Aggregations compute analytics over search results — counting documents
  per category, computing average prices, building histograms, etc.

  ## Examples

      alias Muninn.Aggregation
      alias Muninn.Aggregation.{Bucket, Metric}

      # Simple terms aggregation
      aggs = Aggregation.new()
        |> Aggregation.add("categories", Bucket.terms("category", size: 10))

      {:ok, results} = Muninn.Searcher.aggregate(searcher, "*", ["title"], aggs)

      # Nested: stats per category
      aggs = Aggregation.new()
        |> Aggregation.add("categories",
          Bucket.terms("category", size: 10)
          |> Aggregation.sub("price_stats", Metric.stats("price"))
        )

  """

  @type t :: map()

  @doc "Creates a new empty aggregation request."
  @spec new() :: t()
  def new, do: %{}

  @doc "Adds a named aggregation to the request."
  @spec add(t(), String.t(), map()) :: t()
  def add(aggs, name, aggregation) when is_binary(name) and is_map(aggregation) do
    Map.put(aggs, name, aggregation)
  end

  @doc "Adds a sub-aggregation to a bucket aggregation."
  @spec sub(map(), String.t(), map()) :: map()
  def sub(parent_agg, name, child_agg) do
    sub_aggs = Map.get(parent_agg, "aggs", %{})
    Map.put(parent_agg, "aggs", Map.put(sub_aggs, name, child_agg))
  end
end
