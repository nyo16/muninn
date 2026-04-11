defmodule Muninn.AggregationTest do
  use ExUnit.Case, async: true

  alias Muninn.Aggregation
  alias Muninn.Aggregation.{Bucket, Metric}

  describe "builder DSL" do
    test "new/0 creates empty map" do
      assert Aggregation.new() == %{}
    end

    test "add/3 adds aggregation" do
      aggs =
        Aggregation.new()
        |> Aggregation.add("avg_price", Metric.avg("price"))

      assert aggs == %{"avg_price" => %{"avg" => %{"field" => "price"}}}
    end

    test "sub/3 adds sub-aggregation" do
      parent = Bucket.terms("category")

      result =
        parent
        |> Aggregation.sub("avg_price", Metric.avg("price"))

      assert result["aggs"]["avg_price"] == %{"avg" => %{"field" => "price"}}
    end

    test "multiple aggregations" do
      aggs =
        Aggregation.new()
        |> Aggregation.add("avg_price", Metric.avg("price"))
        |> Aggregation.add("max_price", Metric.max("price"))

      assert Map.has_key?(aggs, "avg_price")
      assert Map.has_key?(aggs, "max_price")
    end
  end

  describe "bucket builders" do
    test "terms with options" do
      result = Bucket.terms("category", size: 10, min_doc_count: 2)
      assert result["terms"]["field"] == "category"
      assert result["terms"]["size"] == 10
      assert result["terms"]["min_doc_count"] == 2
    end

    test "range" do
      ranges = [%{"to" => 50.0}, %{"from" => 50.0, "to" => 100.0}, %{"from" => 100.0}]
      result = Bucket.range("price", ranges)
      assert result["range"]["field"] == "price"
      assert result["range"]["ranges"] == ranges
    end

    test "histogram" do
      result = Bucket.histogram("price", 10.0, min_doc_count: 1)
      assert result["histogram"]["field"] == "price"
      assert result["histogram"]["interval"] == 10.0
      assert result["histogram"]["min_doc_count"] == 1
    end
  end

  describe "metric builders" do
    test "avg" do
      assert Metric.avg("price") == %{"avg" => %{"field" => "price"}}
    end

    test "sum" do
      assert Metric.sum("price") == %{"sum" => %{"field" => "price"}}
    end

    test "min" do
      assert Metric.min("price") == %{"min" => %{"field" => "price"}}
    end

    test "max" do
      assert Metric.max("price") == %{"max" => %{"field" => "price"}}
    end

    test "stats" do
      assert Metric.stats("price") == %{"stats" => %{"field" => "price"}}
    end

    test "cardinality with precision" do
      result = Metric.cardinality("category", precision_threshold: 100)
      assert result["cardinality"]["field"] == "category"
      assert result["cardinality"]["precision_threshold"] == 100
    end

    test "percentiles with custom percents" do
      result = Metric.percentiles("price", percents: [25, 50, 75, 99])
      assert result["percentiles"]["field"] == "price"
      assert result["percentiles"]["percents"] == [25, 50, 75, 99]
    end
  end
end
