defmodule Muninn.CountTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema}

  setup do
    test_path = "/tmp/muninn_count_#{:erlang.unique_integer([:positive])}"
    on_exit(fn -> Muninn.TestHelpers.safe_rm_rf(test_path) end)
    {:ok, test_path: test_path}
  end

  describe "count/3" do
    test "returns 0 on empty index", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true)
      {:ok, index} = Index.create(test_path, schema)
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, count} = Searcher.count(searcher, "anything", ["title"])
      assert count == 0
    end

    test "returns correct count for matching documents", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "Elixir Programming"})
      IndexWriter.add_document(index, %{"title" => "Elixir in Action"})
      IndexWriter.add_document(index, %{"title" => "Phoenix Framework"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, count} = Searcher.count(searcher, "elixir", ["title"])
      assert count == 2
    end

    test "returns 0 for non-matching query", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "Elixir Programming"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, count} = Searcher.count(searcher, "rust", ["title"])
      assert count == 0
    end

    test "works with boolean queries", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "Elixir and Phoenix"})
      IndexWriter.add_document(index, %{"title" => "Elixir Basics"})
      IndexWriter.add_document(index, %{"title" => "Phoenix Guide"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, count} = Searcher.count(searcher, "elixir AND phoenix", ["title"])
      assert count == 1
    end
  end
end
