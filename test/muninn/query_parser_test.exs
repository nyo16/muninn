defmodule Muninn.QueryParserTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema}

  setup do
    test_path = "/tmp/muninn_query_parser_#{:erlang.unique_integer([:positive])}"

    on_exit(fn ->
      File.rm_rf!(test_path)
    end)

    {:ok, test_path: test_path}
  end

  describe "field-specific search (field:value)" do
    test "searches specific field with colon syntax", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "elixir guide", "content" => "rust is fast"})

      IndexWriter.add_document(index, %{
        "title" => "rust guide",
        "content" => "elixir is functional"
      })

      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Search for "elixir" only in title field
      {:ok, results} = Searcher.search_query(searcher, "title:elixir", ["title", "content"])

      assert results["total_hits"] == 1
      assert List.first(results["hits"])["doc"]["title"] == "elixir guide"
    end

    test "searches specific field among multiple fields", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("author", stored: true, indexed: true)
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{
        "title" => "Phoenix Framework",
        "author" => "Chris McCord",
        "content" => "Web development"
      })

      IndexWriter.add_document(index, %{
        "title" => "Elixir Basics",
        "author" => "Jose Valim",
        "content" => "Chris mentioned this"
      })

      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Search for "chris" only in author field
      {:ok, results} = Searcher.search_query(searcher, "author:chris", ["title", "content"])

      assert results["total_hits"] == 1
      assert List.first(results["hits"])["doc"]["author"] == "Chris McCord"
    end

    test "field:value doesn't match other fields", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "other", "content" => "phoenix framework"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Search for "phoenix" only in title (should not find it in content)
      {:ok, results} = Searcher.search_query(searcher, "title:phoenix", ["title", "content"])

      assert results["total_hits"] == 0
    end
  end

  describe "boolean AND queries" do
    test "finds documents matching both terms with AND", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"content" => "elixir is great"})
      IndexWriter.add_document(index, %{"content" => "phoenix is great"})
      IndexWriter.add_document(index, %{"content" => "elixir phoenix framework"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, "elixir AND phoenix", ["content"])

      assert results["total_hits"] == 1
      assert String.contains?(List.first(results["hits"])["doc"]["content"], "elixir phoenix")
    end

    test "AND with field-specific queries", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "elixir guide", "content" => "web stuff"})

      IndexWriter.add_document(index, %{
        "title" => "elixir guide",
        "content" => "phoenix framework"
      })

      IndexWriter.add_document(index, %{"title" => "other", "content" => "phoenix framework"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} =
        Searcher.search_query(searcher, "title:elixir AND content:phoenix", [
          "title",
          "content"
        ])

      assert results["total_hits"] == 1
      hit = List.first(results["hits"])
      assert hit["doc"]["title"] == "elixir guide"
      assert String.contains?(hit["doc"]["content"], "phoenix")
    end

    test "returns empty for AND when one term missing", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"content" => "elixir programming"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, "elixir AND rust", ["content"])

      assert results["total_hits"] == 0
    end
  end

  describe "boolean OR queries" do
    test "finds documents matching either term with OR", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"content" => "elixir programming"})
      IndexWriter.add_document(index, %{"content" => "rust programming"})
      IndexWriter.add_document(index, %{"content" => "java programming"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, "elixir OR rust", ["content"])

      assert results["total_hits"] == 2

      contents = Enum.map(results["hits"], & &1["doc"]["content"])
      assert "elixir programming" in contents
      assert "rust programming" in contents
    end

    test "OR with field-specific queries", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "elixir guide", "content" => "basics"})
      IndexWriter.add_document(index, %{"title" => "other", "content" => "phoenix framework"})
      IndexWriter.add_document(index, %{"title" => "java guide", "content" => "enterprise"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} =
        Searcher.search_query(searcher, "title:elixir OR content:phoenix", ["title", "content"])

      assert results["total_hits"] == 2
    end

    test "OR matches at least one term", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"content" => "elixir only"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, "elixir OR nonexistent", ["content"])

      assert results["total_hits"] == 1
    end
  end

  describe "phrase queries" do
    test "finds exact phrase with quotes", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"content" => "functional programming is great"})
      IndexWriter.add_document(index, %{"content" => "programming with functional style"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} =
        Searcher.search_query(searcher, ~s("functional programming"), ["content"])

      assert results["total_hits"] == 1
      assert List.first(results["hits"])["doc"]["content"] == "functional programming is great"
    end

    test "phrase query with field specifier", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{
        "title" => "web framework guide",
        "content" => "other stuff"
      })

      IndexWriter.add_document(index, %{"title" => "web stuff", "content" => "framework guide"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} =
        Searcher.search_query(searcher, ~s(title:"web framework"), ["title", "content"])

      assert results["total_hits"] == 1
      assert List.first(results["hits"])["doc"]["title"] == "web framework guide"
    end

    test "phrase query doesn't match non-adjacent words", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"content" => "elixir is a great language"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, ~s("elixir language"), ["content"])

      assert results["total_hits"] == 0
    end
  end

  describe "required (+) and excluded (-) terms" do
    test "required term with + prefix", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"content" => "elixir phoenix"})
      IndexWriter.add_document(index, %{"content" => "elixir ecto"})
      IndexWriter.add_document(index, %{"content" => "phoenix framework"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Require elixir, optionally include phoenix
      {:ok, results} = Searcher.search_query(searcher, "+elixir phoenix", ["content"])

      assert results["total_hits"] == 2

      for hit <- results["hits"] do
        assert String.contains?(hit["doc"]["content"], "elixir")
      end
    end

    test "excluded term with - prefix", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"content" => "elixir phoenix web"})
      IndexWriter.add_document(index, %{"content" => "elixir ecto database"})
      IndexWriter.add_document(index, %{"content" => "elixir language"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Find elixir but exclude phoenix
      {:ok, results} = Searcher.search_query(searcher, "elixir -phoenix", ["content"])

      assert results["total_hits"] == 2

      for hit <- results["hits"] do
        refute String.contains?(hit["doc"]["content"], "phoenix")
      end
    end

    test "combining + and - operators", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"content" => "elixir web draft"})
      IndexWriter.add_document(index, %{"content" => "elixir web published"})
      IndexWriter.add_document(index, %{"content" => "elixir language"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, "+elixir +web -draft", ["content"])

      assert results["total_hits"] == 1
      assert List.first(results["hits"])["doc"]["content"] == "elixir web published"
    end
  end

  describe "complex queries" do
    test "combining AND, OR with parentheses", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"content" => "elixir web phoenix"})
      IndexWriter.add_document(index, %{"content" => "elixir concurrent otp"})
      IndexWriter.add_document(index, %{"content" => "rust web actix"})
      IndexWriter.add_document(index, %{"content" => "elixir data ecto"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} =
        Searcher.search_query(searcher, "elixir AND (web OR concurrent)", ["content"])

      assert results["total_hits"] == 2

      contents = Enum.map(results["hits"], & &1["doc"]["content"])
      assert "elixir web phoenix" in contents
      assert "elixir concurrent otp" in contents
    end

    test "complex field-specific with boolean operators", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("content", stored: true, indexed: true)
        |> Schema.add_text_field("tags", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{
        "title" => "elixir web guide",
        "content" => "phoenix framework tutorial",
        "tags" => "beginner published"
      })

      IndexWriter.add_document(index, %{
        "title" => "elixir concurrency",
        "content" => "otp genserver",
        "tags" => "advanced published"
      })

      IndexWriter.add_document(index, %{
        "title" => "elixir web advanced",
        "content" => "phoenix internals",
        "tags" => "advanced draft"
      })

      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} =
        Searcher.search_query(
          searcher,
          "title:elixir AND (content:phoenix OR content:otp) AND tags:published",
          ["title", "content", "tags"]
        )

      assert results["total_hits"] == 2
    end

    test "phrase combined with boolean", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"content" => "functional programming in elixir"})
      IndexWriter.add_document(index, %{"content" => "object oriented programming in java"})

      IndexWriter.add_document(index, %{
        "content" => "functional programming in haskell"
      })

      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} =
        Searcher.search_query(searcher, ~s("functional programming" AND elixir), ["content"])

      assert results["total_hits"] == 1

      assert List.first(results["hits"])["doc"]["content"] ==
               "functional programming in elixir"
    end
  end

  describe "default fields behavior" do
    test "searches across all default fields when no field specified", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "elixir basics", "content" => "other"})
      IndexWriter.add_document(index, %{"title" => "other", "content" => "elixir advanced"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, "elixir", ["title", "content"])

      # Should find elixir in both title and content
      assert results["total_hits"] == 2
    end

    test "single default field works correctly", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "elixir guide", "content" => "rust content"})
      IndexWriter.add_document(index, %{"title" => "rust guide", "content" => "elixir content"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Search only in title
      {:ok, results} = Searcher.search_query(searcher, "elixir", ["title"])

      assert results["total_hits"] == 1
      assert List.first(results["hits"])["doc"]["title"] == "elixir guide"
    end
  end

  describe "error handling" do
    test "returns error for invalid field name", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:error, reason} =
        Searcher.search_query(searcher, "test", ["nonexistent_field"])

      assert String.contains?(reason, "not found in schema")
    end

    test "returns error for malformed query", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Unclosed quote is a parse error
      {:error, reason} = Searcher.search_query(searcher, ~s("unclosed), ["title"])

      assert String.contains?(reason, "Failed to parse query")
    end
  end

  describe "case insensitivity" do
    test "query parser is case insensitive", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"content" => "Elixir Programming Language"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, "elixir", ["content"])
      assert results["total_hits"] == 1

      {:ok, results} = Searcher.search_query(searcher, "ELIXIR", ["content"])
      assert results["total_hits"] == 1

      {:ok, results} = Searcher.search_query(searcher, "content:programming", ["content"])
      assert results["total_hits"] == 1
    end
  end
end
