defmodule Muninn.Aggregation.Bucket do
  @moduledoc """
  Bucket aggregation builders.

  Bucket aggregations group documents into buckets based on field values,
  ranges, or other criteria.
  """

  @doc """
  Groups documents by field values.

  ## Options

    * `:size` - Maximum number of buckets to return
    * `:min_doc_count` - Minimum document count for a bucket to be included
    * `:order` - Sort order for buckets (e.g., `%{"_count" => "asc"}`)

  ## Examples

      Bucket.terms("category", size: 10)

  """
  @spec terms(String.t(), keyword()) :: map()
  def terms(field, opts \\ []) do
    inner = %{"field" => field}

    inner =
      opts
      |> Enum.reduce(inner, fn
        {:size, v}, acc -> Map.put(acc, "size", v)
        {:order, v}, acc -> Map.put(acc, "order", v)
        {:min_doc_count, v}, acc -> Map.put(acc, "min_doc_count", v)
        _, acc -> acc
      end)

    %{"terms" => inner}
  end

  @doc """
  Groups documents by numeric ranges.

  ## Examples

      Bucket.range("price", [
        %{"to" => 50.0},
        %{"from" => 50.0, "to" => 100.0},
        %{"from" => 100.0}
      ])

  """
  @spec range(String.t(), list(map())) :: map()
  def range(field, ranges) do
    %{"range" => %{"field" => field, "ranges" => ranges}}
  end

  @doc """
  Groups documents into fixed-width numeric buckets.

  ## Options

    * `:offset` - Bucket boundary offset
    * `:min_doc_count` - Minimum document count

  ## Examples

      Bucket.histogram("price", 10.0)

  """
  @spec histogram(String.t(), number(), keyword()) :: map()
  def histogram(field, interval, opts \\ []) do
    inner = %{"field" => field, "interval" => interval}

    inner =
      opts
      |> Enum.reduce(inner, fn
        {:offset, v}, acc -> Map.put(acc, "offset", v)
        {:min_doc_count, v}, acc -> Map.put(acc, "min_doc_count", v)
        _, acc -> acc
      end)

    %{"histogram" => inner}
  end

  @doc """
  Filters documents for sub-aggregations.

  ## Examples

      Bucket.filter(%{"term" => %{"status" => "active"}})

  """
  @spec filter(map()) :: map()
  def filter(filter_query) do
    %{"filter" => filter_query}
  end
end
