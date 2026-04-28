defmodule Muninn.BytesFieldTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema}

  setup do
    test_path = "/tmp/muninn_bytes_#{:erlang.unique_integer([:positive])}"
    on_exit(fn -> Muninn.TestHelpers.safe_rm_rf(test_path) end)
    {:ok, test_path: test_path}
  end

  describe "bytes field type" do
    test "round-trip binary storage and retrieval", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)
        |> Schema.add_bytes_field("payload", stored: true)

      {:ok, index} = Index.create(test_path, schema)

      binary_data = <<1, 2, 3, 4, 5, 255, 0, 128>>
      IndexWriter.add_document(index, %{"title" => "test doc", "payload" => binary_data})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, "test", ["title"], limit: 10)

      assert results["total_hits"] == 1
      hit = List.first(results["hits"])
      assert hit["doc"]["title"] == "test doc"
      assert hit["doc"]["payload"] == binary_data
    end

    test "empty binary data", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)
        |> Schema.add_bytes_field("data", stored: true)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "empty", "data" => <<>>})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, "empty", ["title"], limit: 10)
      assert results["total_hits"] == 1
      assert List.first(results["hits"])["doc"]["data"] == <<>>
    end

    test "bytes field with stored: false is not returned", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)
        |> Schema.add_bytes_field("hidden", stored: false)

      {:ok, index} = Index.create(test_path, schema)

      IndexWriter.add_document(index, %{"title" => "doc", "hidden" => <<1, 2, 3>>})
      IndexWriter.commit(index)

      {:ok, reader} = IndexReader.new(index)
      {:ok, searcher} = Searcher.new(reader)

      {:ok, results} = Searcher.search_query(searcher, "doc", ["title"], limit: 10)
      assert results["total_hits"] == 1
      refute Map.has_key?(List.first(results["hits"])["doc"], "hidden")
    end

    test "schema includes bytes field", %{test_path: _test_path} do
      schema = Schema.new() |> Schema.add_bytes_field("data", stored: true)
      assert length(schema.fields) == 1
      assert hd(schema.fields).type == :bytes
      assert hd(schema.fields).name == "data"
    end
  end
end
