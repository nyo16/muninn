defmodule Muninn.TokenizerTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema}

  setup do
    test_path = "/tmp/muninn_tokenizer_#{:erlang.unique_integer([:positive])}"
    on_exit(fn -> Muninn.TestHelpers.safe_rm_rf(test_path) end)
    {:ok, test_path: test_path}
  end

  describe "default tokenizer" do
    test "splits and lowercases as before", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true)
      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "Hello World"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, "hello", ["title"])
      assert results["total_hits"] == 1

      {:ok, results} = Searcher.search_query(searcher, "world", ["title"])
      assert results["total_hits"] == 1
    end
  end

  describe "en_stem tokenizer" do
    test "stems English words", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true, tokenizer: "en_stem")

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"content" => "running quickly"})
      IndexWriter.add_document(index, %{"content" => "she runs every morning"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # "run" should match both "running" and "runs" via stemming
      {:ok, results} = Searcher.search_query(searcher, "run", ["content"])
      assert results["total_hits"] == 2
    end

    test "stemming matches plural forms", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true, tokenizer: "en_stem")

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"content" => "the cats sat on the mat"})
      IndexWriter.add_document(index, %{"content" => "a cat on a mat"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, "cat", ["content"])
      assert results["total_hits"] == 2
    end
  end

  describe "raw tokenizer" do
    test "stores entire field value as single token", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("category", stored: true, tokenizer: "raw")

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"category" => "Hello World"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # Exact match of full value should work
      {:ok, results} = Searcher.search_query(searcher, ~s(category:"Hello World"), ["category"])
      assert results["total_hits"] == 1

      # Partial word should NOT match with raw tokenizer
      {:ok, results} = Searcher.search_query(searcher, "hello", ["category"])
      assert results["total_hits"] == 0
    end
  end

  describe "whitespace tokenizer" do
    test "splits on whitespace only", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true, tokenizer: "whitespace")

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"content" => "hello-world foo_bar"})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # "hello-world" is kept as one token (whitespace tokenizer doesn't split on hyphens)
      {:ok, results} = Searcher.search_query(searcher, "hello-world", ["content"])
      assert results["total_hits"] == 1

      # "foo_bar" is also one token
      {:ok, results} = Searcher.search_query(searcher, "foo_bar", ["content"])
      assert results["total_hits"] == 1
    end
  end

  describe "different tokenizers on same schema" do
    test "fields can use different tokenizers", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, tokenizer: "default")
        |> Schema.add_text_field("keyword", stored: true, tokenizer: "raw")

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{
        "title" => "Hello World",
        "keyword" => "Hello World"
      })

      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      # "hello" matches title (tokenized) but not keyword (raw)
      {:ok, results} = Searcher.search_query(searcher, "title:hello", ["title"])
      assert results["total_hits"] == 1

      {:ok, results} = Searcher.search_query(searcher, "keyword:hello", ["keyword"])
      assert results["total_hits"] == 0
    end
  end

  describe "invalid tokenizer" do
    test "returns error for unknown tokenizer", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, tokenizer: "nonexistent")

      assert {:error, reason} = Index.create(test_path, schema)
      assert reason =~ "Unknown tokenizer"
    end
  end
end
