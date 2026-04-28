defmodule Muninn.RegexQueryTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema}

  setup do
    test_path = "/tmp/muninn_regex_#{:erlang.unique_integer([:positive])}"
    on_exit(fn -> Muninn.TestHelpers.safe_rm_rf(test_path) end)
    {:ok, test_path: test_path}
  end

  describe "search_regex/4" do
    test "basic regex match", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "Elixir Programming"})
      IndexWriter.add_document(index, %{"title" => "Phoenix Framework"})
      IndexWriter.add_document(index, %{"title" => "Erlang Basics"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Match terms starting with "eli"
      {:ok, results} = Searcher.search_regex(searcher, "title", "eli.*")
      assert results["total_hits"] == 1
      assert List.first(results["hits"])["doc"]["title"] == "Elixir Programming"
    end

    test "character class matching", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "cat sat"})
      IndexWriter.add_document(index, %{"title" => "bat mat"})
      IndexWriter.add_document(index, %{"title" => "dog run"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Match terms like [cbm]at
      {:ok, results} = Searcher.search_regex(searcher, "title", "[cbm]at")
      assert results["total_hits"] >= 2
    end

    test "no matches returns 0 hits", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "Hello World"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_regex(searcher, "title", "zzz.*xyz")
      assert results["total_hits"] == 0
    end

    test "invalid regex returns error", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true)
      {:ok, index} = Index.create(test_path, schema)
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:error, reason} = Searcher.search_regex(searcher, "title", "[invalid")
      assert is_binary(reason)
    end

    test "limit is respected", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true)
      {:ok, index} = Index.create(test_path, schema)

      for i <- 1..10 do
        IndexWriter.add_document(index, %{"title" => "item#{i}"})
      end

      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_regex(searcher, "title", "item.*", limit: 3)
      assert length(results["hits"]) == 3
    end

    test "error on non-text field", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)
        |> Schema.add_u64_field("count", stored: true)

      {:ok, index} = Index.create(test_path, schema)
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:error, reason} = Searcher.search_regex(searcher, "count", ".*")
      assert reason =~ "not a text field"
    end
  end
end
