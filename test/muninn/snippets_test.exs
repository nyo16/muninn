defmodule Muninn.SnippetsTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema}

  setup do
    test_path = "/tmp/muninn_snippets_#{:erlang.unique_integer([:positive])}"
    on_exit(fn -> Muninn.TestHelpers.safe_rm_rf(test_path) end)
    {:ok, test_path: test_path}
  end

  defp searcher_for(test_path, schema, docs) do
    {:ok, index} = Index.create(test_path, schema)
    Enum.each(docs, &IndexWriter.add_document(index, &1))
    IndexWriter.commit(index)
    {:ok, reader} = IndexReader.new(index)
    {:ok, searcher} = Searcher.new(reader)
    searcher
  end

  describe "search_with_snippets/5" do
    test "returns a snippet map for the requested field", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("content", stored: true, indexed: true)

      searcher =
        searcher_for(test_path, schema, [
          %{"title" => "Elixir Guide", "content" => "learn elixir programming with this guide"}
        ])

      {:ok, results} =
        Searcher.search_with_snippets(searcher, "elixir", ["title", "content"], ["content"])

      assert results["total_hits"] == 1
      hit = List.first(results["hits"])
      assert is_map(hit["snippets"])
      assert Map.has_key?(hit["snippets"], "content")
      assert is_binary(hit["snippets"]["content"])
    end

    test "highlights the matched term with <b> tags", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("content", stored: true, indexed: true)

      searcher =
        searcher_for(test_path, schema, [%{"content" => "learn elixir programming today"}])

      {:ok, results} =
        Searcher.search_with_snippets(searcher, "elixir", ["content"], ["content"])

      snippet = results["hits"] |> List.first() |> get_in(["snippets", "content"])
      assert snippet =~ "<b>elixir</b>"
    end

    test "supports multiple snippet fields", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("content", stored: true, indexed: true)

      searcher =
        searcher_for(test_path, schema, [
          %{"title" => "elixir basics", "content" => "an elixir tutorial"}
        ])

      {:ok, results} =
        Searcher.search_with_snippets(
          searcher,
          "elixir",
          ["title", "content"],
          ["title", "content"]
        )

      snippets = results["hits"] |> List.first() |> Map.get("snippets")
      assert snippets["title"] =~ "<b>elixir</b>"
      assert snippets["content"] =~ "<b>elixir</b>"
    end

    test "max_snippet_chars truncates long content", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("content", stored: true, indexed: true)

      long =
        String.duplicate("padding words here ", 40) <>
          "elixir " <> String.duplicate("more padding text ", 40)

      searcher = searcher_for(test_path, schema, [%{"content" => long}])

      {:ok, results} =
        Searcher.search_with_snippets(searcher, "elixir", ["content"], ["content"],
          max_snippet_chars: 40
        )

      snippet = results["hits"] |> List.first() |> get_in(["snippets", "content"])
      stripped = String.replace(snippet, ~r{</?b>}, "")

      assert snippet =~ "<b>elixir</b>"
      assert String.length(stripped) < String.length(long)
    end

    test "respects the limit option", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("content", stored: true, indexed: true)

      docs = for i <- 1..5, do: %{"content" => "elixir document number #{i}"}
      searcher = searcher_for(test_path, schema, docs)

      {:ok, results} =
        Searcher.search_with_snippets(searcher, "elixir", ["content"], ["content"], limit: 2)

      # total_hits reflects the number of hits actually returned (capped by limit)
      assert results["total_hits"] == 2
      assert length(results["hits"]) == 2
    end
  end
end
