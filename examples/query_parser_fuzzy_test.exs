#!/usr/bin/env elixir

# Test if QueryParser supports fuzzy syntax (~)
# Usage: mix run examples/query_parser_fuzzy_test.exs

alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema}

# Create test index
test_path = "/tmp/muninn_qp_fuzzy_test"
File.rm_rf!(test_path)

IO.puts("Testing QueryParser fuzzy syntax support...\n")

schema = Schema.new()
  |> Schema.add_text_field("title", stored: true, indexed: true)
  |> Schema.add_u64_field("views", stored: true, indexed: true)

{:ok, index} = Index.create(test_path, schema)

# Index documents
documents = [
  %{"title" => "Elixir Programming", "views" => 1000},
  %{"title" => "Phoenix Framework", "views" => 2000},
  %{"title" => "Erlang Guide", "views" => 500}
]

Enum.each(documents, &IndexWriter.add_document(index, &1))
IndexWriter.commit(index)

{:ok, reader} = IndexReader.new(index)
{:ok, searcher} = Searcher.new(reader)

# Test 1: Try fuzzy syntax with default distance
IO.puts("Test 1: title:elixr~ (default distance)")
case Searcher.search_query(searcher, "title:elixr~", ["title"]) do
  {:ok, results} ->
    IO.puts("✓ QueryParser supports fuzzy syntax!")
    IO.puts("  Found #{results["total_hits"]} results")
    for hit <- results["hits"] do
      IO.puts("  - #{hit["doc"]["title"]}")
    end
  {:error, reason} ->
    IO.puts("✗ QueryParser does NOT support fuzzy syntax")
    IO.puts("  Error: #{reason}")
end

# Test 2: Try fuzzy with custom distance
IO.puts("\nTest 2: title:phoneix~2 (distance=2)")
case Searcher.search_query(searcher, "title:phoneix~2", ["title"]) do
  {:ok, results} ->
    IO.puts("✓ QueryParser supports fuzzy with distance!")
    IO.puts("  Found #{results["total_hits"]} results")
    for hit <- results["hits"] do
      IO.puts("  - #{hit["doc"]["title"]}")
    end
  {:error, reason} ->
    IO.puts("✗ QueryParser does NOT support fuzzy with distance")
    IO.puts("  Error: #{reason}")
end

# Test 3: Try combining fuzzy with range query
IO.puts("\nTest 3: title:elixr~ AND views:[500 TO 1500] (combined)")
case Searcher.search_query(searcher, "title:elixr~ AND views:[500 TO 1500]", ["title"]) do
  {:ok, results} ->
    IO.puts("✓ QueryParser supports combined fuzzy + range!")
    IO.puts("  Found #{results["total_hits"]} results")
    for hit <- results["hits"] do
      IO.puts("  - #{hit["doc"]["title"]} (views: #{hit["doc"]["views"]})")
    end
  {:error, reason} ->
    IO.puts("✗ QueryParser does NOT support combined fuzzy + range")
    IO.puts("  Error: #{reason}")
end

# Cleanup
File.rm_rf!(test_path)
IO.puts("\n=== QueryParser Fuzzy Syntax Test Complete ===")
