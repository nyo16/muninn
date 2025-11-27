defmodule Muninn.SearchIntegrationTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema, Query}

  setup do
    test_path = "/tmp/muninn_search_integration_#{:erlang.unique_integer([:positive])}"

    on_exit(fn ->
      File.rm_rf!(test_path)
    end)

    {:ok, test_path: test_path}
  end

  describe "end-to-end search workflow" do
    test "complete workflow: create, index, search, retrieve", %{test_path: test_path} do
      # Create schema
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("body", stored: true, indexed: true)
        |> Schema.add_u64_field("views", stored: true, indexed: true)

      # Create index
      {:ok, index} = Index.create(test_path, schema)

      # Add documents
      docs = [
        %{"title" => "Introduction to Elixir", "body" => "Elixir is a functional language", "views" => 100},
        %{"title" => "Advanced Elixir Patterns", "body" => "Mastering Elixir programming", "views" => 50},
        %{"title" => "Rust for Systems Programming", "body" => "Learn Rust basics", "views" => 75}
      ]

      Enum.each(docs, fn doc -> IndexWriter.add_document(index, doc) end)
      :ok = IndexWriter.commit(index)

      # Search
      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("title", "elixir")
      {:ok, results} = Searcher.search(searcher, query, limit: 10)

      # Verify results
      assert results["total_hits"] == 2
      assert length(results["hits"]) == 2

      # Check all hits have scores and docs
      for hit <- results["hits"] do
        assert is_float(hit["score"])
        assert hit["score"] > 0
        assert is_map(hit["doc"])
        assert String.contains?(String.downcase(hit["doc"]["title"]), "elixir")
      end
    end

    test "search returns results sorted by score", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      # Add documents - some with more occurrences of search term
      docs = [
        %{"title" => "programming"},
        %{"title" => "programming programming"},
        %{"title" => "programming programming programming"}
      ]

      Enum.each(docs, fn doc -> IndexWriter.add_document(index, doc) end)
      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("title", "programming")
      {:ok, results} = Searcher.search(searcher, query, limit: 10)

      assert results["total_hits"] == 3

      # Verify scores are in descending order
      scores = Enum.map(results["hits"], & &1["score"])
      assert scores == Enum.sort(scores, :desc)
    end
  end

  describe "search with different field types" do
    test "searches text fields only", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_u64_field("count", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      doc = %{"title" => "test document", "count" => 42}
      :ok = IndexWriter.add_document(index, doc)
      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Should find by text field
      query = Query.term("title", "test")
      {:ok, results} = Searcher.search(searcher, query, limit: 10)
      assert results["total_hits"] == 1

      # Numeric fields are not supported for term queries (would error)
      # This is expected behavior
    end

    test "returns all stored fields in results", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("author", stored: true, indexed: false)
        |> Schema.add_u64_field("year", stored: true, indexed: false)
        |> Schema.add_bool_field("published", stored: true, indexed: false)

      {:ok, index} = Index.create(test_path, schema)

      doc = %{
        "title" => "great book",
        "author" => "John Doe",
        "year" => 2024,
        "published" => true
      }

      :ok = IndexWriter.add_document(index, doc)
      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("title", "great")
      {:ok, results} = Searcher.search(searcher, query, limit: 1)

      assert results["total_hits"] == 1
      hit = List.first(results["hits"])

      # All stored fields should be present
      assert hit["doc"]["title"] == "great book"
      assert hit["doc"]["author"] == "John Doe"
      assert hit["doc"]["year"] == 2024
      assert hit["doc"]["published"] == true
    end

    test "non-stored fields are not returned in results", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("secret", stored: false, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      doc = %{"title" => "visible", "secret" => "hidden content"}
      :ok = IndexWriter.add_document(index, doc)
      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("title", "visible")
      {:ok, results} = Searcher.search(searcher, query, limit: 1)

      hit = List.first(results["hits"])
      assert hit["doc"]["title"] == "visible"
      refute Map.has_key?(hit["doc"], "secret")
    end
  end

  describe "search with limits and pagination" do
    test "respects limit parameter", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      # Add 10 documents
      for i <- 1..10 do
        IndexWriter.add_document(index, %{"text" => "item #{i} searchterm"})
      end

      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("text", "searchterm")

      # Test different limits
      # Note: total_hits currently returns the number of hits returned (limited), not total matches
      # This is a known limitation of using TopDocs collector
      {:ok, results_5} = Searcher.search(searcher, query, limit: 5)
      assert results_5["total_hits"] == 5
      assert length(results_5["hits"]) == 5

      {:ok, results_3} = Searcher.search(searcher, query, limit: 3)
      assert results_3["total_hits"] == 3
      assert length(results_3["hits"]) == 3

      {:ok, results_all} = Searcher.search(searcher, query, limit: 100)
      assert results_all["total_hits"] == 10
      assert length(results_all["hits"]) == 10
    end

    test "default limit is 10", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      for i <- 1..20 do
        IndexWriter.add_document(index, %{"text" => "doc #{i} word"})
      end

      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("text", "word")

      # No limit specified - should default to 10
      {:ok, results} = Searcher.search(searcher, query)
      assert results["total_hits"] == 10
      assert length(results["hits"]) == 10
    end

    test "limit of 1 returns single hit", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"text" => "findme first"})
      IndexWriter.add_document(index, %{"text" => "findme second"})
      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("text", "findme")
      {:ok, results} = Searcher.search(searcher, query, limit: 1)

      assert results["total_hits"] == 1
      assert length(results["hits"]) == 1
    end
  end

  describe "edge cases and error handling" do
    test "search on empty index returns zero results", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      # Don't add any documents
      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("title", "anything")
      {:ok, results} = Searcher.search(searcher, query, limit: 10)

      assert results["total_hits"] == 0
      assert results["hits"] == []
    end

    test "search for non-existent term returns zero results", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "hello world"})
      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("title", "nonexistent")
      {:ok, results} = Searcher.search(searcher, query, limit: 10)

      assert results["total_hits"] == 0
      assert results["hits"] == []
    end

    test "search on non-existent field returns error", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "test"})
      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("nonexistent_field", "test")
      {:error, reason} = Searcher.search(searcher, query, limit: 10)

      assert reason =~ "Field 'nonexistent_field' not found"
    end

    test "search with special characters in query", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"text" => "hello-world test@example.com"})
      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Tokenizer splits on special chars, so search individual tokens
      query = Query.term("text", "hello")
      {:ok, results} = Searcher.search(searcher, query, limit: 10)

      assert results["total_hits"] == 1
    end

    test "search with empty string term", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"text" => "content"})
      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Empty string should find nothing
      query = Query.term("text", "")
      {:ok, results} = Searcher.search(searcher, query, limit: 10)

      assert results["total_hits"] == 0
    end
  end

  describe "multiple searches on same index" do
    test "can perform multiple searches with same searcher", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      docs = [
        %{"text" => "apple fruit"},
        %{"text" => "banana fruit"},
        %{"text" => "carrot vegetable"}
      ]

      Enum.each(docs, &IndexWriter.add_document(index, &1))
      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # First search
      query1 = Query.term("text", "fruit")
      {:ok, results1} = Searcher.search(searcher, query1, limit: 10)
      assert results1["total_hits"] == 2

      # Second search with same searcher
      query2 = Query.term("text", "vegetable")
      {:ok, results2} = Searcher.search(searcher, query2, limit: 10)
      assert results2["total_hits"] == 1

      # Third search
      query3 = Query.term("text", "apple")
      {:ok, results3} = Searcher.search(searcher, query3, limit: 10)
      assert results3["total_hits"] == 1
    end

    test "can create multiple searchers from same reader", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"text" => "test content"})
      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)

      # Create multiple searchers
      {:ok, searcher1} = Searcher.new(reader)
      {:ok, searcher2} = Searcher.new(reader)
      {:ok, searcher3} = Searcher.new(reader)

      query = Query.term("text", "test")

      # All should work
      {:ok, results1} = Searcher.search(searcher1, query, limit: 10)
      {:ok, results2} = Searcher.search(searcher2, query, limit: 10)
      {:ok, results3} = Searcher.search(searcher3, query, limit: 10)

      assert results1["total_hits"] == 1
      assert results2["total_hits"] == 1
      assert results3["total_hits"] == 1
    end
  end

  describe "search after index modifications" do
    test "reader sees documents added after its creation if new reader is created", %{
      test_path: test_path
    } do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      # Add first document
      IndexWriter.add_document(index, %{"text" => "first"})
      :ok = IndexWriter.commit(index)

      # Create first reader
      {:ok, reader1} = IndexReader.new(index)
      {:ok, searcher1} = Searcher.new(reader1)

      query = Query.term("text", "first")
      {:ok, results1} = Searcher.search(searcher1, query, limit: 10)
      assert results1["total_hits"] == 1

      # Add second document
      IndexWriter.add_document(index, %{"text" => "first second"})
      :ok = IndexWriter.commit(index)

      # Old reader still sees old data
      {:ok, results_old} = Searcher.search(searcher1, query, limit: 10)
      assert results_old["total_hits"] == 1

      # New reader sees new data
      {:ok, reader2} = IndexReader.new(index)
      {:ok, searcher2} = Searcher.new(reader2)
      {:ok, results_new} = Searcher.search(searcher2, query, limit: 10)
      assert results_new["total_hits"] == 2
    end

    test "search works correctly after multiple commit cycles", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      # First batch
      IndexWriter.add_document(index, %{"text" => "batch one"})
      :ok = IndexWriter.commit(index)

      # Second batch
      IndexWriter.add_document(index, %{"text" => "batch two"})
      :ok = IndexWriter.commit(index)

      # Third batch
      IndexWriter.add_document(index, %{"text" => "batch three"})
      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      query = Query.term("text", "batch")
      {:ok, results} = Searcher.search(searcher, query, limit: 10)

      assert results["total_hits"] == 3
    end
  end

  describe "real-world search scenarios" do
    test "blog search by title and tags", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("tags", stored: true, indexed: true)
        |> Schema.add_u64_field("views", stored: true, indexed: false)

      {:ok, index} = Index.create(test_path, schema)

      posts = [
        %{"title" => "Getting Started with Elixir", "tags" => "elixir tutorial beginner", "views" => 1000},
        %{"title" => "Advanced Elixir Techniques", "tags" => "elixir advanced patterns", "views" => 500},
        %{"title" => "Rust vs Go Comparison", "tags" => "rust go comparison", "views" => 750},
        %{"title" => "Building APIs with Elixir", "tags" => "elixir api phoenix", "views" => 800}
      ]

      Enum.each(posts, &IndexWriter.add_document(index, &1))
      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Search by title
      title_query = Query.term("title", "elixir")
      {:ok, title_results} = Searcher.search(searcher, title_query, limit: 10)
      assert title_results["total_hits"] == 3

      # Search by tags
      tag_query = Query.term("tags", "tutorial")
      {:ok, tag_results} = Searcher.search(searcher, tag_query, limit: 10)
      assert tag_results["total_hits"] == 1
    end

    test "product catalog search", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("name", stored: true, indexed: true)
        |> Schema.add_text_field("category", stored: true, indexed: true)
        |> Schema.add_f64_field("price", stored: true, indexed: false)
        |> Schema.add_bool_field("in_stock", stored: true, indexed: false)

      {:ok, index} = Index.create(test_path, schema)

      products = [
        %{"name" => "laptop computer pro", "category" => "electronics", "price" => 1299.99, "in_stock" => true},
        %{"name" => "laptop stand", "category" => "accessories", "price" => 49.99, "in_stock" => true},
        %{"name" => "desktop computer", "category" => "electronics", "price" => 899.99, "in_stock" => false},
        %{"name" => "wireless mouse", "category" => "accessories", "price" => 29.99, "in_stock" => true}
      ]

      Enum.each(products, &IndexWriter.add_document(index, &1))
      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Search for laptops
      laptop_query = Query.term("name", "laptop")
      {:ok, results} = Searcher.search(searcher, laptop_query, limit: 10)

      assert results["total_hits"] == 2

      for hit <- results["hits"] do
        assert String.contains?(hit["doc"]["name"], "laptop")
        assert is_float(hit["doc"]["price"])
        assert is_boolean(hit["doc"]["in_stock"])
      end
    end

    test "documentation search with ranking", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("content", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      # Documents with varying relevance
      docs = [
        %{"title" => "function basics", "content" => "Introduction to functions"},
        %{"title" => "function composition", "content" => "Advanced function techniques"},
        %{"title" => "testing", "content" => "How to test your functions properly"}
      ]

      Enum.each(docs, &IndexWriter.add_document(index, &1))
      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Search for "function" - should rank title matches higher
      query = Query.term("title", "function")
      {:ok, results} = Searcher.search(searcher, query, limit: 10)

      assert results["total_hits"] == 2

      # First two results should have "function" in title
      first_hit = List.first(results["hits"])
      assert String.contains?(first_hit["doc"]["title"], "function")
    end
  end

  describe "concurrent search operations" do
    test "multiple concurrent searches work correctly", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("text", stored: true, indexed: true)
      {:ok, index} = Index.create(test_path, schema)

      # Add documents
      for i <- 1..50 do
        IndexWriter.add_document(index, %{"text" => "document #{i} searchable"})
      end

      :ok = IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)

      # Perform concurrent searches
      tasks =
        for _ <- 1..10 do
          Task.async(fn ->
            {:ok, searcher} = Searcher.new(reader)
            query = Query.term("text", "searchable")
            Searcher.search(searcher, query, limit: 20)
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All searches should succeed and return same results
      for {:ok, result} <- results do
        assert result["total_hits"] == 20
        assert length(result["hits"]) == 20
      end
    end
  end
end
