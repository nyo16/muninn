defmodule Muninn.Aggregation.Metric do
  @moduledoc """
  Metric aggregation builders.

  Metric aggregations compute numeric values (averages, sums, etc.)
  over document fields.
  """

  @doc "Computes the average of a numeric field."
  @spec avg(String.t()) :: map()
  def avg(field), do: %{"avg" => %{"field" => field}}

  @doc "Computes the sum of a numeric field."
  @spec sum(String.t()) :: map()
  def sum(field), do: %{"sum" => %{"field" => field}}

  @doc "Computes the minimum value of a numeric field."
  @spec min(String.t()) :: map()
  def min(field), do: %{"min" => %{"field" => field}}

  @doc "Computes the maximum value of a numeric field."
  @spec max(String.t()) :: map()
  def max(field), do: %{"max" => %{"field" => field}}

  @doc "Computes count, min, max, avg, and sum at once."
  @spec stats(String.t()) :: map()
  def stats(field), do: %{"stats" => %{"field" => field}}

  @doc "Counts values in a field."
  @spec count(String.t()) :: map()
  def count(field), do: %{"value_count" => %{"field" => field}}

  @doc """
  Computes approximate distinct count using HyperLogLog.

  ## Options

    * `:precision_threshold` - Precision/memory trade-off (default: 3000)

  """
  @spec cardinality(String.t(), keyword()) :: map()
  def cardinality(field, opts \\ []) do
    inner = %{"field" => field}

    inner =
      case Keyword.get(opts, :precision_threshold) do
        nil -> inner
        threshold -> Map.put(inner, "precision_threshold", threshold)
      end

    %{"cardinality" => inner}
  end

  @doc """
  Computes percentiles of a numeric field.

  ## Options

    * `:percents` - List of percentile values to compute (default: [1, 5, 25, 50, 75, 95, 99])

  """
  @spec percentiles(String.t(), keyword()) :: map()
  def percentiles(field, opts \\ []) do
    inner = %{"field" => field}

    inner =
      case Keyword.get(opts, :percents) do
        nil -> inner
        percents -> Map.put(inner, "percents", percents)
      end

    %{"percentiles" => inner}
  end
end
