defmodule Muninn.RangeQueryTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema}

  setup do
    test_path = "/tmp/muninn_range_#{:erlang.unique_integer([:positive])}"

    on_exit(fn ->
      File.rm_rf!(test_path)
    end)

    {:ok, test_path: test_path}
  end

  describe "QueryParser range syntax" do
    test "u64 inclusive range [low TO high]", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_u64_field("count", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"count" => 50})
      IndexWriter.add_document(index, %{"count" => 100})
      IndexWriter.add_document(index, %{"count" => 500})
      IndexWriter.add_document(index, %{"count" => 1000})
      IndexWriter.add_document(index, %{"count" => 5000})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, "count:[100 TO 1000]", ["count"])

      assert results["total_hits"] == 3
      counts = Enum.map(results["hits"], & &1["doc"]["count"])
      assert 100 in counts
      assert 500 in counts
      assert 1000 in counts
    end

    test "f64 range for prices", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_f64_field("price", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"price" => 9.99})
      IndexWriter.add_document(index, %{"price" => 49.99})
      IndexWriter.add_document(index, %{"price" => 99.99})
      IndexWriter.add_document(index, %{"price" => 199.99})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, "price:[40.0 TO 150.0]", ["price"])

      assert results["total_hits"] == 2
      prices = Enum.map(results["hits"], & &1["doc"]["price"])
      assert 49.99 in prices
      assert 99.99 in prices
    end

    test "i64 range for negative numbers", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_i64_field("temp", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"temp" => -20})
      IndexWriter.add_document(index, %{"temp" => -10})
      IndexWriter.add_document(index, %{"temp" => 0})
      IndexWriter.add_document(index, %{"temp" => 10})
      IndexWriter.add_document(index, %{"temp" => 20})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, "temp:[-15 TO 15]", ["temp"])

      assert results["total_hits"] == 3
      temps = Enum.map(results["hits"], & &1["doc"]["temp"])
      assert -10 in temps
      assert 0 in temps
      assert 10 in temps
    end

    test "open-ended range with wildcard", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_u64_field("views", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"views" => 100})
      IndexWriter.add_document(index, %{"views" => 500})
      IndexWriter.add_document(index, %{"views" => 5000})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, "views:[1000 TO *]", ["views"])

      assert results["total_hits"] == 1
      assert List.first(results["hits"])["doc"]["views"] == 5000
    end

    test "range combined with text search", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("category", stored: true, indexed: true)
        |> Schema.add_f64_field("price", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"category" => "electronics", "price" => 99.99})
      IndexWriter.add_document(index, %{"category" => "books", "price" => 19.99})
      IndexWriter.add_document(index, %{"category" => "electronics", "price" => 499.99})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} =
        Searcher.search_query(
          searcher,
          "category:electronics AND price:[50.0 TO 200.0]",
          ["category"]
        )

      assert results["total_hits"] == 1
      hit = List.first(results["hits"])
      assert hit["doc"]["category"] == "electronics"
      assert hit["doc"]["price"] == 99.99
    end
  end

  describe "search_range_u64/5" do
    test "inclusive both bounds", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_u64_field("value", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"value" => 10})
      IndexWriter.add_document(index, %{"value" => 50})
      IndexWriter.add_document(index, %{"value" => 100})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} =
        Searcher.search_range_u64(searcher, "value", 10, 100, inclusive: :both)

      assert results["total_hits"] == 3
    end

    test "inclusive lower bound only", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_u64_field("value", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"value" => 10})
      IndexWriter.add_document(index, %{"value" => 50})
      IndexWriter.add_document(index, %{"value" => 100})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} =
        Searcher.search_range_u64(searcher, "value", 10, 100, inclusive: :lower)

      assert results["total_hits"] == 2
      values = Enum.map(results["hits"], & &1["doc"]["value"])
      assert 10 in values
      assert 50 in values
      refute 100 in values
    end

    test "exclusive both bounds", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_u64_field("value", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"value" => 10})
      IndexWriter.add_document(index, %{"value" => 50})
      IndexWriter.add_document(index, %{"value" => 100})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} =
        Searcher.search_range_u64(searcher, "value", 10, 100, inclusive: :neither)

      assert results["total_hits"] == 1
      assert List.first(results["hits"])["doc"]["value"] == 50
    end

    test "returns error for non-u64 field", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:error, reason} = Searcher.search_range_u64(searcher, "text", 1, 10)

      assert String.contains?(reason, "not a u64 field")
    end
  end

  describe "search_range_i64/5" do
    test "range spanning negative and positive", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_i64_field("offset", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"offset" => -100})
      IndexWriter.add_document(index, %{"offset" => -50})
      IndexWriter.add_document(index, %{"offset" => 0})
      IndexWriter.add_document(index, %{"offset" => 50})
      IndexWriter.add_document(index, %{"offset" => 100})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_range_i64(searcher, "offset", -60, 60)

      assert results["total_hits"] == 3
      offsets = Enum.map(results["hits"], & &1["doc"]["offset"])
      assert -50 in offsets
      assert 0 in offsets
      assert 50 in offsets
    end

    test "only negative values", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_i64_field("value", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"value" => -100})
      IndexWriter.add_document(index, %{"value" => -50})
      IndexWriter.add_document(index, %{"value" => -10})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_range_i64(searcher, "value", -60, -20)

      assert results["total_hits"] == 1
      assert List.first(results["hits"])["doc"]["value"] == -50
    end
  end

  describe "search_range_f64/5" do
    test "decimal ranges", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_f64_field("rating", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"rating" => 2.5})
      IndexWriter.add_document(index, %{"rating" => 3.7})
      IndexWriter.add_document(index, %{"rating" => 4.2})
      IndexWriter.add_document(index, %{"rating" => 4.8})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_range_f64(searcher, "rating", 4.0, 5.0)

      assert results["total_hits"] == 2
      ratings = Enum.map(results["hits"], & &1["doc"]["rating"])
      assert 4.2 in ratings
      assert 4.8 in ratings
    end

    test "precise boundary matching", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_f64_field("value", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"value" => 10.0})
      IndexWriter.add_document(index, %{"value" => 10.5})
      IndexWriter.add_document(index, %{"value" => 11.0})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} =
        Searcher.search_range_f64(searcher, "value", 10.0, 11.0, inclusive: :both)

      assert results["total_hits"] == 3
    end
  end

  describe "limit parameter" do
    test "respects limit in range queries", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_u64_field("value", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      for i <- 1..10 do
        IndexWriter.add_document(index, %{"value" => i * 10})
      end

      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_range_u64(searcher, "value", 10, 100, limit: 3)

      assert length(results["hits"]) == 3
    end
  end

  describe "edge cases" do
    test "empty range returns no results", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_u64_field("value", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"value" => 100})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_range_u64(searcher, "value", 200, 300)

      assert results["total_hits"] == 0
    end

    test "single value range", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_u64_field("value", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"value" => 50})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_range_u64(searcher, "value", 50, 50, inclusive: :both)

      assert results["total_hits"] == 1
    end
  end
end
