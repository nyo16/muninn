defmodule Muninn.MoreLikeThisTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema}

  setup do
    test_path = "/tmp/muninn_mlt_#{:erlang.unique_integer([:positive])}"
    on_exit(fn -> Muninn.TestHelpers.safe_rm_rf(test_path) end)
    {:ok, test_path: test_path}
  end

  describe "search_more_like_this/3" do
    test "finds similar documents", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true)

      {:ok, index} = Index.create(test_path, schema)

      # Create a corpus with overlapping vocabulary
      docs = [
        "elixir is a functional programming language",
        "elixir runs on the erlang virtual machine",
        "phoenix is a web framework for elixir",
        "rust is a systems programming language",
        "rust provides memory safety without garbage collection",
        "python is a popular programming language",
        "python is great for data science",
        "java is an object oriented programming language",
        "java runs on the jvm virtual machine",
        "ruby is a dynamic programming language"
      ]

      Enum.each(docs, fn doc ->
        IndexWriter.add_document(index, %{"content" => doc})
      end)

      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Find docs similar to "elixir programming"
      {:ok, results} =
        Searcher.search_more_like_this(
          searcher,
          %{"content" => "elixir is a programming language"},
          min_doc_freq: 1,
          min_term_freq: 1,
          limit: 5
        )

      assert results["total_hits"] >= 1
      # Results should include docs about elixir or programming
      contents = Enum.map(results["hits"], & &1["doc"]["content"])
      assert Enum.any?(contents, &String.contains?(&1, "elixir"))
    end

    test "returns empty results when no similar documents", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"content" => "hello world"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Use a completely unrelated document with high min_doc_freq to find nothing
      {:ok, results} =
        Searcher.search_more_like_this(
          searcher,
          %{"content" => "zzzzzzz xyzxyz uniqueterm"},
          min_doc_freq: 1,
          min_term_freq: 1,
          limit: 5
        )

      assert results["total_hits"] == 0
    end

    test "empty document fields returns error", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true)

      {:ok, index} = Index.create(test_path, schema)
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:error, reason} = Searcher.search_more_like_this(searcher, %{})
      assert reason =~ "empty"
    end
  end
end
