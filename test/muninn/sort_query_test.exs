defmodule Muninn.SortQueryTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema}

  setup do
    test_path = "/tmp/muninn_sort_#{:erlang.unique_integer([:positive])}"
    on_exit(fn -> Muninn.TestHelpers.safe_rm_rf(test_path) end)
    {:ok, test_path: test_path}
  end

  defp create_product_index(test_path) do
    schema =
      Schema.new()
      |> Schema.add_text_field("title", stored: true)
      |> Schema.add_u64_field("views", stored: true, fast: true)
      |> Schema.add_i64_field("score", stored: true, fast: true)
      |> Schema.add_f64_field("price", stored: true, fast: true)

    {:ok, index} = Index.create(test_path, schema)

    IndexWriter.add_document(index, %{
      "title" => "cheap item",
      "views" => 100,
      "score" => -5,
      "price" => 9.99
    })

    IndexWriter.add_document(index, %{
      "title" => "popular item",
      "views" => 5000,
      "score" => 42,
      "price" => 29.99
    })

    IndexWriter.add_document(index, %{
      "title" => "expensive item",
      "views" => 500,
      "score" => 10,
      "price" => 199.99
    })

    IndexWriter.commit(index)

    {:ok, reader} = IndexReader.new(index)
    {:ok, searcher} = Searcher.new(reader)
    searcher
  end

  describe "search_query_sorted/5" do
    test "sort by u64 ascending", %{test_path: test_path} do
      searcher = create_product_index(test_path)

      {:ok, results} =
        Searcher.search_query_sorted(searcher, "item", ["title"], "views", limit: 10)

      hits = results["hits"]
      assert length(hits) == 3
      views = Enum.map(hits, & &1["doc"]["views"])
      assert views == [100, 500, 5000]
    end

    test "sort by u64 descending", %{test_path: test_path} do
      searcher = create_product_index(test_path)

      {:ok, results} =
        Searcher.search_query_sorted(searcher, "item", ["title"], "views",
          reverse: true,
          limit: 10
        )

      hits = results["hits"]
      views = Enum.map(hits, & &1["doc"]["views"])
      assert views == [5000, 500, 100]
    end

    test "sort by i64 with negative values", %{test_path: test_path} do
      searcher = create_product_index(test_path)

      {:ok, results} =
        Searcher.search_query_sorted(searcher, "item", ["title"], "score", limit: 10)

      hits = results["hits"]
      scores = Enum.map(hits, & &1["doc"]["score"])
      assert scores == [-5, 10, 42]
    end

    test "sort by f64", %{test_path: test_path} do
      searcher = create_product_index(test_path)

      {:ok, results} =
        Searcher.search_query_sorted(searcher, "item", ["title"], "price",
          reverse: true,
          limit: 10
        )

      hits = results["hits"]
      prices = Enum.map(hits, & &1["doc"]["price"])
      assert prices == [199.99, 29.99, 9.99]
    end

    test "results include sort_value", %{test_path: test_path} do
      searcher = create_product_index(test_path)

      {:ok, results} =
        Searcher.search_query_sorted(searcher, "item", ["title"], "views", limit: 10)

      hit = List.first(results["hits"])
      assert Map.has_key?(hit, "sort_value")
    end

    test "limit is respected", %{test_path: test_path} do
      searcher = create_product_index(test_path)

      {:ok, results} =
        Searcher.search_query_sorted(searcher, "item", ["title"], "price", limit: 2)

      assert length(results["hits"]) == 2
    end

    test "error on non-numeric sort field", %{test_path: test_path} do
      searcher = create_product_index(test_path)

      {:error, reason} =
        Searcher.search_query_sorted(searcher, "item", ["title"], "title", limit: 10)

      assert reason =~ "numeric"
    end
  end
end
