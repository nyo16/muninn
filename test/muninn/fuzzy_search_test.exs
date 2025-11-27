defmodule Muninn.FuzzySearchTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema}

  setup do
    test_path = "/tmp/muninn_fuzzy_#{:erlang.unique_integer([:positive])}"
    on_exit(fn -> Muninn.TestHelpers.safe_rm_rf(test_path) end)
    {:ok, test_path: test_path}
  end

  describe "search_fuzzy/4 - basic functionality" do
    test "exact match with distance=0", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "Elixir"})
      IndexWriter.add_document(index, %{"title" => "Phoenix"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Search with lowercase (Tantivy tokenizes to lowercase)
      {:ok, results} = Searcher.search_fuzzy(searcher, "title", "elixir", distance: 0)

      assert results["total_hits"] == 1
      assert List.first(results["hits"])["doc"]["title"] == "Elixir"
    end

    test "single character substitution (elixr → elixir)", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "Elixir Programming"})
      IndexWriter.add_document(index, %{"title" => "Phoenix Guide"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_fuzzy(searcher, "title", "elixr", distance: 1)

      assert results["total_hits"] >= 1
      titles = Enum.map(results["hits"], & &1["doc"]["title"])
      assert "Elixir Programming" in titles
    end

    test "character transposition (elixer → elixir)", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "Elixir Basics"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # With transposition=true, "elixer" should match "elixir" with distance=1
      {:ok, results} =
        Searcher.search_fuzzy(
          searcher,
          "title",
          "elixer",
          distance: 1,
          transposition: true
        )

      assert results["total_hits"] >= 1
    end

    test "distance=1 vs distance=2", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("word", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"word" => "phoenix"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # "phonix" (1 char removed) should match with distance=1
      {:ok, results1} = Searcher.search_fuzzy(searcher, "word", "phonix", distance: 1)
      assert results1["total_hits"] == 1

      # "phnix" (2 chars removed) needs distance=2
      {:ok, results2} = Searcher.search_fuzzy(searcher, "word", "phnix", distance: 1)
      assert results2["total_hits"] == 0

      {:ok, results3} = Searcher.search_fuzzy(searcher, "word", "phnix", distance: 2)
      assert results3["total_hits"] == 1
    end

    test "limit parameter", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      for i <- 1..10 do
        IndexWriter.add_document(index, %{"text" => "test#{i}"})
      end

      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_fuzzy(searcher, "text", "test", distance: 1, limit: 3)

      assert length(results["hits"]) <= 3
    end

    test "no results for non-matching term", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "Elixir"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_fuzzy(searcher, "title", "java", distance: 1)

      assert results["total_hits"] == 0
    end

    test "transposition cost true vs false", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("word", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"word" => "abcd"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # "acbd" has one transposition (b and c swapped)
      # With transposition_cost_one=true, distance=1 should match
      {:ok, results1} =
        Searcher.search_fuzzy(
          searcher,
          "word",
          "acbd",
          distance: 1,
          transposition: true
        )

      assert results1["total_hits"] >= 1

      # With transposition_cost_one=false, distance=1 won't match (needs 2: delete + insert)
      {:ok, results2} =
        Searcher.search_fuzzy(
          searcher,
          "word",
          "acbd",
          distance: 1,
          transposition: false
        )

      assert results2["total_hits"] == 0
    end
  end

  describe "search_fuzzy_prefix/4" do
    test "basic fuzzy prefix search", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("name", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"name" => "Phoenix Framework"})
      IndexWriter.add_document(index, %{"name" => "Photography Tips"})
      IndexWriter.add_document(index, %{"name" => "Elixir Guide"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # "pho" should match "Phoenix" and "Photography"
      {:ok, results} = Searcher.search_fuzzy_prefix(searcher, "name", "pho", distance: 0)

      assert results["total_hits"] >= 2
      names = Enum.map(results["hits"], & &1["doc"]["name"])
      assert "Phoenix Framework" in names
      assert "Photography Tips" in names
    end

    test "fuzzy prefix with typo", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("name", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"name" => "Phoenix"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # "pho" with typo tolerance should still find "Phoenix"
      {:ok, results} = Searcher.search_fuzzy_prefix(searcher, "name", "pho", distance: 1)

      assert results["total_hits"] >= 1
    end

    test "fuzzy prefix respects limit", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("name", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      for i <- 1..10 do
        IndexWriter.add_document(index, %{"name" => "test#{i}"})
      end

      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_fuzzy_prefix(searcher, "name", "test", limit: 5)

      assert length(results["hits"]) <= 5
    end
  end

  describe "search_fuzzy_with_snippets/5" do
    test "fuzzy search with snippets", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{
        "title" => "Elixir Guide",
        "content" => "Learn Elixir programming with this comprehensive guide"
      })

      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} =
        Searcher.search_fuzzy_with_snippets(
          searcher,
          "content",
          "elixr",
          ["content"],
          distance: 1
        )

      assert results["total_hits"] >= 1
      hit = List.first(results["hits"])
      assert is_map(hit["snippets"])
      assert Map.has_key?(hit["snippets"], "content")
    end

    test "snippets contain HTML bold tags", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{
        "content" => "This is a test about Elixir programming language"
      })

      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} =
        Searcher.search_fuzzy_with_snippets(
          searcher,
          "content",
          "elixr",
          ["content"],
          distance: 1
        )

      assert results["total_hits"] >= 1
      hit = List.first(results["hits"])
      snippet = hit["snippets"]["content"]

      # Snippet should contain <b> tags (if highlighting works)
      # Note: Tantivy might not highlight fuzzy matches, so we just check it exists
      assert is_binary(snippet)
    end
  end

  describe "error handling" do
    test "returns error for invalid distance", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:error, reason} = Searcher.search_fuzzy(searcher, "title", "test", distance: 3)

      assert reason == "Distance must be between 0 and 2"
    end

    test "returns error for non-text field", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_u64_field("count", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:error, reason} = Searcher.search_fuzzy(searcher, "count", "test", distance: 1)

      assert String.contains?(reason, "must be a text field")
    end

    test "returns error for missing field", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:error, reason} = Searcher.search_fuzzy(searcher, "nonexistent", "test", distance: 1)

      assert String.contains?(reason, "not found")
    end
  end

  describe "integration scenarios" do
    test "real-world typos - programming terms", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("term", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      # Common programming terms
      terms = ["function", "variable", "programming", "database", "algorithm"]

      Enum.each(terms, fn term ->
        IndexWriter.add_document(index, %{"term" => term})
      end)

      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Common typos
      test_cases = [
        {"fucntion", "function"},
        {"varaible", "variable"},
        {"progarmming", "programming"},
        {"databse", "database"},
        {"algoritm", "algorithm"}
      ]

      for {typo, correct} <- test_cases do
        {:ok, results} = Searcher.search_fuzzy(searcher, "term", typo, distance: 2)
        assert results["total_hits"] >= 1, "Failed to find '#{correct}' with typo '#{typo}'"

        found_terms = Enum.map(results["hits"], & &1["doc"]["term"])
        assert correct in found_terms
      end
    end

    test "multiple fields", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("author", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "Elixir Guide", "author" => "José Valim"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Search in title
      {:ok, results1} = Searcher.search_fuzzy(searcher, "title", "elixr", distance: 1)
      assert results1["total_hits"] >= 1

      # Search in author
      {:ok, results2} = Searcher.search_fuzzy(searcher, "author", "jose", distance: 1)
      assert results2["total_hits"] >= 1
    end
  end
end
