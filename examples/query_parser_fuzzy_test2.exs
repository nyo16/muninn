#!/usr/bin/env elixir

# Debug test for QueryParser fuzzy syntax
# Usage: mix run examples/query_parser_fuzzy_test2.exs

alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema}

test_path = "/tmp/muninn_qp_fuzzy_test2"
File.rm_rf!(test_path)

IO.puts("Debug: Testing exact vs fuzzy search\n")

schema = Schema.new()
  |> Schema.add_text_field("title", stored: true, indexed: true)

{:ok, index} = Index.create(test_path, schema)

# Index documents
documents = [
  %{"title" => "Elixir Programming"},
  %{"title" => "Phoenix Framework"}
]

Enum.each(documents, &IndexWriter.add_document(index, &1))
IndexWriter.commit(index)

{:ok, reader} = IndexReader.new(index)
{:ok, searcher} = Searcher.new(reader)

# Test exact match first
IO.puts("1. Exact search: title:elixir")
{:ok, results} = Searcher.search_query(searcher, "title:elixir", ["title"])
IO.puts("   Found #{results["total_hits"]} results")

# Test lowercase exact
IO.puts("\n2. Exact search: elixir")
{:ok, results} = Searcher.search_query(searcher, "elixir", ["title"])
IO.puts("   Found #{results["total_hits"]} results")

# Test fuzzy with dedicated function
IO.puts("\n3. Dedicated fuzzy function: search_fuzzy('elixr')")
{:ok, results} = Searcher.search_fuzzy(searcher, "title", "elixr", distance: 1)
IO.puts("   Found #{results["total_hits"]} results")
for hit <- results["hits"] do
  IO.puts("   - #{hit["doc"]["title"]}")
end

# Test QueryParser fuzzy
IO.puts("\n4. QueryParser fuzzy: title:elixr~")
{:ok, results} = Searcher.search_query(searcher, "title:elixr~", ["title"])
IO.puts("   Found #{results["total_hits"]} results")

IO.puts("\n5. QueryParser fuzzy with distance: title:elixr~1")
{:ok, results} = Searcher.search_query(searcher, "title:elixr~1", ["title"])
IO.puts("   Found #{results["total_hits"]} results")

File.rm_rf!(test_path)
