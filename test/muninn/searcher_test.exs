defmodule Muninn.SearcherTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema, Query}

  setup do
    test_path = "/tmp/muninn_searcher_#{:erlang.unique_integer([:positive])}"

    on_exit(fn ->
      File.rm_rf!(test_path)
    end)

    {:ok, test_path: test_path}
  end

  describe "IndexReader" do
    test "creates reader from index", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      {:ok, reader} = IndexReader.new(index)
      assert is_reference(reader)
    end

    test "can create multiple readers from same index", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      {:ok, reader1} = IndexReader.new(index)
      {:ok, reader2} = IndexReader.new(index)
      {:ok, reader3} = IndexReader.new(index)

      assert is_reference(reader1)
      assert is_reference(reader2)
      assert is_reference(reader3)
    end

    test "reader can be created from reopened index", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index1} = Index.create(test_path, schema)

      IndexWriter.add_document(index1, %{"title" => "test"})
      IndexWriter.commit(index1)

      # Reopen index
      {:ok, index2} = Index.open(test_path)
      {:ok, reader} = IndexReader.new(index2)

      assert is_reference(reader)
    end
  end

  describe "Searcher" do
    test "creates searcher from reader", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      assert is_reference(searcher)
    end

    test "can create multiple searchers from same reader", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      {:ok, reader} = IndexReader.new(index)

      {:ok, searcher1} = Searcher.new(reader)
      {:ok, searcher2} = Searcher.new(reader)

      assert is_reference(searcher1)
      assert is_reference(searcher2)
    end
  end

  describe "basic term search" do
    test "finds documents by exact term match", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "hello world"})
      IndexWriter.add_document(index, %{"title" => "goodbye world"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("title", "hello")
      {:ok, results} = Searcher.search(searcher, query, limit: 10)

      assert results["total_hits"] == 1
      assert length(results["hits"]) == 1

      hit = List.first(results["hits"])
      assert hit["doc"]["title"] == "hello world"
      assert is_float(hit["score"])
      assert hit["score"] > 0
    end

    test "finds multiple documents matching term", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      docs = [
        %{"title" => "hello world"},
        %{"title" => "goodbye world"},
        %{"title" => "hello universe"}
      ]

      Enum.each(docs, &IndexWriter.add_document(index, &1))
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("title", "hello")
      {:ok, results} = Searcher.search(searcher, query, limit: 10)

      assert results["total_hits"] == 2
      assert length(results["hits"]) == 2

      for hit <- results["hits"] do
        assert String.contains?(hit["doc"]["title"], "hello")
        assert is_float(hit["score"])
      end
    end

    test "returns empty results when no matches", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "hello world"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("title", "nonexistent")
      {:ok, results} = Searcher.search(searcher, query, limit: 10)

      assert results["total_hits"] == 0
      assert results["hits"] == []
    end

    test "search is case-insensitive due to tokenization", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "HELLO WORLD"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Search with lowercase should still match
      query = Query.term("title", "hello")
      {:ok, results} = Searcher.search(searcher, query, limit: 10)

      assert results["total_hits"] == 1
    end
  end

  describe "search result format" do
    test "results contain total_hits and hits array", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"text" => "test"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("text", "test")
      {:ok, results} = Searcher.search(searcher, query, limit: 10)

      assert is_map(results)
      assert Map.has_key?(results, "total_hits")
      assert Map.has_key?(results, "hits")
      assert is_integer(results["total_hits"])
      assert is_list(results["hits"])
    end

    test "each hit contains score and doc", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"text" => "test content"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("text", "test")
      {:ok, results} = Searcher.search(searcher, query, limit: 10)

      hit = List.first(results["hits"])

      assert is_map(hit)
      assert Map.has_key?(hit, "score")
      assert Map.has_key?(hit, "doc")
      assert is_float(hit["score"])
      assert is_map(hit["doc"])
    end

    test "scores are positive floats", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      for i <- 1..5 do
        IndexWriter.add_document(index, %{"text" => "item #{i} searchterm"})
      end

      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("text", "searchterm")
      {:ok, results} = Searcher.search(searcher, query, limit: 10)

      for hit <- results["hits"] do
        assert is_float(hit["score"])
        assert hit["score"] > 0.0
      end
    end
  end

  describe "Query.Term" do
    test "creates term query struct", %{test_path: test_path} do
      query = Query.term("field", "value")

      assert query.__struct__ == Muninn.Query.Term
      assert query.field == "field"
      assert query.value == "value"
    end

    test "requires string field and value" do
      query = Query.term("title", "test")

      assert is_binary(query.field)
      assert is_binary(query.value)
    end
  end

  describe "search options" do
    test "accepts limit option", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      for i <- 1..5 do
        IndexWriter.add_document(index, %{"text" => "doc #{i}"})
      end

      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("text", "doc")

      {:ok, results} = Searcher.search(searcher, query, limit: 3)
      assert length(results["hits"]) == 3
    end

    test "uses default limit when not specified", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"text" => "test"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("text", "test")

      # No limit specified - should use default (10)
      {:ok, results} = Searcher.search(searcher, query)
      assert is_list(results["hits"])
    end
  end
end
