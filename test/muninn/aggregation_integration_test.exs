defmodule Muninn.AggregationIntegrationTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema}
  alias Muninn.Aggregation
  alias Muninn.Aggregation.{Bucket, Metric}

  setup do
    test_path = "/tmp/muninn_agg_int_#{:erlang.unique_integer([:positive])}"
    on_exit(fn -> Muninn.TestHelpers.safe_rm_rf(test_path) end)
    {:ok, test_path: test_path}
  end

  defp create_product_index(test_path) do
    schema =
      Schema.new()
      |> Schema.add_text_field("title", stored: true)
      |> Schema.add_text_field("category", stored: true, tokenizer: "raw", fast: true)
      |> Schema.add_f64_field("price", stored: true, fast: true)
      |> Schema.add_u64_field("quantity", stored: true, fast: true)

    {:ok, index} = Index.create(test_path, schema)

    products = [
      %{"title" => "laptop", "category" => "electronics", "price" => 999.0, "quantity" => 5},
      %{"title" => "phone", "category" => "electronics", "price" => 699.0, "quantity" => 20},
      %{"title" => "tablet", "category" => "electronics", "price" => 499.0, "quantity" => 15},
      %{"title" => "shirt", "category" => "clothing", "price" => 29.0, "quantity" => 100},
      %{"title" => "pants", "category" => "clothing", "price" => 49.0, "quantity" => 80},
      %{"title" => "book", "category" => "books", "price" => 15.0, "quantity" => 200}
    ]

    Enum.each(products, &IndexWriter.add_document(index, &1))
    IndexWriter.commit(index)

    {:ok, reader} = IndexReader.new(index)
    {:ok, searcher} = Searcher.new(reader)
    searcher
  end

  describe "stats aggregation" do
    test "computes stats over all documents", %{test_path: test_path} do
      searcher = create_product_index(test_path)

      aggs =
        Aggregation.new()
        |> Aggregation.add("price_stats", Metric.stats("price"))

      {:ok, results} = Searcher.aggregate(searcher, "*", ["title"], aggs)

      stats = results["price_stats"]
      assert stats["count"] == 6
      assert stats["min"] == 15.0
      assert stats["max"] == 999.0
      assert_in_delta stats["avg"], 381.66, 1.0
    end
  end

  describe "avg aggregation" do
    test "computes average price", %{test_path: test_path} do
      searcher = create_product_index(test_path)

      aggs =
        Aggregation.new()
        |> Aggregation.add("avg_price", Metric.avg("price"))

      {:ok, results} = Searcher.aggregate(searcher, "*", ["title"], aggs)
      assert_in_delta results["avg_price"]["value"], 381.66, 1.0
    end
  end

  describe "terms aggregation" do
    test "groups by category", %{test_path: test_path} do
      searcher = create_product_index(test_path)

      aggs =
        Aggregation.new()
        |> Aggregation.add("by_category", Bucket.terms("category", size: 10))

      {:ok, results} = Searcher.aggregate(searcher, "*", ["title"], aggs)

      buckets = results["by_category"]["buckets"]
      assert length(buckets) == 3

      electronics = Enum.find(buckets, &(&1["key"] == "electronics"))
      assert electronics["doc_count"] == 3

      clothing = Enum.find(buckets, &(&1["key"] == "clothing"))
      assert clothing["doc_count"] == 2

      books = Enum.find(buckets, &(&1["key"] == "books"))
      assert books["doc_count"] == 1
    end
  end

  describe "nested aggregations" do
    test "stats per category", %{test_path: test_path} do
      searcher = create_product_index(test_path)

      aggs =
        Aggregation.new()
        |> Aggregation.add(
          "by_category",
          Bucket.terms("category", size: 10)
          |> Aggregation.sub("price_stats", Metric.stats("price"))
        )

      {:ok, results} = Searcher.aggregate(searcher, "*", ["title"], aggs)

      buckets = results["by_category"]["buckets"]
      electronics = Enum.find(buckets, &(&1["key"] == "electronics"))
      assert electronics["price_stats"]["count"] == 3
      assert electronics["price_stats"]["min"] == 499.0
      assert electronics["price_stats"]["max"] == 999.0
    end
  end

  describe "range aggregation" do
    test "groups by price ranges", %{test_path: test_path} do
      searcher = create_product_index(test_path)

      aggs =
        Aggregation.new()
        |> Aggregation.add(
          "price_ranges",
          Bucket.range("price", [
            %{"to" => 50.0},
            %{"from" => 50.0, "to" => 500.0},
            %{"from" => 500.0}
          ])
        )

      {:ok, results} = Searcher.aggregate(searcher, "*", ["title"], aggs)

      buckets = results["price_ranges"]["buckets"]
      assert length(buckets) == 3

      # Under 50: book (15), shirt (29), pants (49)
      cheap = Enum.find(buckets, &(&1["to"] == 50.0))
      assert cheap["doc_count"] == 3

      # 50-500: tablet (499)
      mid = Enum.find(buckets, &(&1["from"] == 50.0 && &1["to"] == 500.0))
      assert mid["doc_count"] == 1

      # 500+: laptop (999), phone (699)
      expensive = Enum.find(buckets, &(&1["from"] == 500.0))
      assert expensive["doc_count"] == 2
    end
  end

  describe "histogram aggregation" do
    test "creates fixed-width buckets", %{test_path: test_path} do
      searcher = create_product_index(test_path)

      aggs =
        Aggregation.new()
        |> Aggregation.add("price_hist", Bucket.histogram("price", 100.0))

      {:ok, results} = Searcher.aggregate(searcher, "*", ["title"], aggs)

      buckets = results["price_hist"]["buckets"]
      assert is_list(buckets)
      assert length(buckets) > 0
    end
  end

  describe "query-scoped aggregation" do
    test "aggregates only matching documents", %{test_path: test_path} do
      searcher = create_product_index(test_path)

      aggs =
        Aggregation.new()
        |> Aggregation.add("price_stats", Metric.stats("price"))

      # Only aggregate electronics (search for electronics in category)
      {:ok, results} =
        Searcher.aggregate(searcher, "category:electronics", ["title", "category"], aggs)

      stats = results["price_stats"]
      assert stats["count"] == 3
      assert stats["min"] == 499.0
    end
  end

  describe "multiple aggregations" do
    test "runs multiple aggregations at once", %{test_path: test_path} do
      searcher = create_product_index(test_path)

      aggs =
        Aggregation.new()
        |> Aggregation.add("avg_price", Metric.avg("price"))
        |> Aggregation.add("max_price", Metric.max("price"))
        |> Aggregation.add("min_price", Metric.min("price"))

      {:ok, results} = Searcher.aggregate(searcher, "*", ["title"], aggs)

      assert results["min_price"]["value"] == 15.0
      assert results["max_price"]["value"] == 999.0
      assert_in_delta results["avg_price"]["value"], 381.66, 1.0
    end
  end

  describe "error handling" do
    test "invalid aggregation JSON returns error", %{test_path: test_path} do
      searcher = create_product_index(test_path)

      {:error, reason} =
        Searcher.aggregate(searcher, "*", ["title"], "{invalid json")

      assert reason =~ "Failed to parse"
    end
  end
end
