defmodule Muninn.PrefixTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema}

  setup do
    test_path = "/tmp/muninn_prefix_#{:erlang.unique_integer([:positive])}"
    on_exit(fn -> Muninn.TestHelpers.safe_rm_rf(test_path) end)
    {:ok, test_path: test_path}
  end

  defp searcher_for(test_path, docs) do
    schema = Schema.new() |> Schema.add_text_field("title", stored: true, indexed: true)
    {:ok, index} = Index.create(test_path, schema)
    Enum.each(docs, &IndexWriter.add_document(index, &1))
    IndexWriter.commit(index)
    {:ok, reader} = IndexReader.new(index)
    {:ok, searcher} = Searcher.new(reader)
    searcher
  end

  describe "search_prefix/4" do
    test "matches documents whose term starts with the prefix", %{test_path: test_path} do
      searcher =
        searcher_for(test_path, [
          %{"title" => "Phoenix Framework"},
          %{"title" => "Photography Tips"},
          %{"title" => "Elixir Guide"}
        ])

      {:ok, results} = Searcher.search_prefix(searcher, "title", "pho", limit: 10)

      assert results["total_hits"] == 2
      titles = Enum.map(results["hits"], & &1["doc"]["title"])
      assert "Phoenix Framework" in titles
      assert "Photography Tips" in titles
      refute "Elixir Guide" in titles
    end

    test "narrows results as the prefix grows (typeahead)", %{test_path: test_path} do
      searcher =
        searcher_for(test_path, [
          %{"title" => "program"},
          %{"title" => "programming"},
          %{"title" => "progress"},
          %{"title" => "project"}
        ])

      {:ok, r1} = Searcher.search_prefix(searcher, "title", "pro", limit: 10)
      {:ok, r2} = Searcher.search_prefix(searcher, "title", "progr", limit: 10)
      {:ok, r3} = Searcher.search_prefix(searcher, "title", "program", limit: 10)

      assert r1["total_hits"] == 4
      assert r2["total_hits"] == 3
      assert r3["total_hits"] == 2
    end

    test "respects the limit option", %{test_path: test_path} do
      docs = for i <- 1..10, do: %{"title" => "testitem#{i}"}
      searcher = searcher_for(test_path, docs)

      {:ok, results} = Searcher.search_prefix(searcher, "title", "testitem", limit: 5)

      assert length(results["hits"]) <= 5
    end

    test "returns no hits for a non-matching prefix", %{test_path: test_path} do
      searcher = searcher_for(test_path, [%{"title" => "Elixir"}, %{"title" => "Phoenix"}])

      {:ok, results} = Searcher.search_prefix(searcher, "title", "zzz", limit: 10)

      assert results["total_hits"] == 0
      assert results["hits"] == []
    end
  end
end
