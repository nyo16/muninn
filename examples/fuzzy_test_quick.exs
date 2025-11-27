#!/usr/bin/env elixir

# Quick fuzzy search test
# Usage: mix run examples/fuzzy_test_quick.exs

alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema}

# Create test index
test_path = "/tmp/muninn_fuzzy_quick_test"
File.rm_rf!(test_path)

IO.puts("Creating test index...")

schema = Schema.new()
  |> Schema.add_text_field("title", stored: true, indexed: true)
  |> Schema.add_text_field("content", stored: true, indexed: true)

{:ok, index} = Index.create(test_path, schema)

# Index some documents
documents = [
  %{"title" => "Getting Started with Elixir", "content" => "Learn Elixir programming"},
  %{"title" => "Phoenix Framework Guide", "content" => "Build web applications"},
  %{"title" => "Erlang and Elixir", "content" => "Two great languages"},
  %{"title" => "Programming in Elixir", "content" => "Advanced Elixir techniques"}
]

Enum.each(documents, &IndexWriter.add_document(index, &1))
IndexWriter.commit(index)

{:ok, reader} = IndexReader.new(index)
{:ok, searcher} = Searcher.new(reader)

IO.puts("\n=== Fuzzy Search Tests ===\n")

# Test 1: Basic fuzzy search with typo
IO.puts("Test 1: Searching for 'elixr' (typo) with distance=1")
{:ok, results} = Searcher.search_fuzzy(searcher, "title", "elixr", distance: 1)
IO.puts("Found #{results["total_hits"]} results:")
for hit <- results["hits"] do
  IO.puts("  - #{hit["doc"]["title"]} (score: #{Float.round(hit["score"], 2)})")
end

# Test 2: Fuzzy prefix search
IO.puts("\nTest 2: Fuzzy prefix search for 'pho' (typo for 'phoenix' prefix)")
{:ok, results} = Searcher.search_fuzzy_prefix(searcher, "title", "pho", distance: 1)
IO.puts("Found #{results["total_hits"]} results:")
for hit <- results["hits"] do
  IO.puts("  - #{hit["doc"]["title"]} (score: #{Float.round(hit["score"], 2)})")
end

# Test 3: Fuzzy with snippets
IO.puts("\nTest 3: Fuzzy search with snippets for 'elixr'")
{:ok, results} = Searcher.search_fuzzy_with_snippets(
  searcher,
  "title",
  "elixr",
  ["title", "content"],
  distance: 1,
  max_snippet_chars: 100
)
IO.puts("Found #{results["total_hits"]} results:")
for hit <- results["hits"] do
  IO.puts("  - #{hit["doc"]["title"]}")
  if hit["snippets"]["title"] do
    IO.puts("    Title snippet: #{hit["snippets"]["title"]}")
  end
  if hit["snippets"]["content"] do
    IO.puts("    Content snippet: #{hit["snippets"]["content"]}")
  end
end

# Test 4: Distance=2 (more tolerant)
IO.puts("\nTest 4: Searching for 'phoneix' (2 typos) with distance=2")
{:ok, results} = Searcher.search_fuzzy(searcher, "title", "phoneix", distance: 2)
IO.puts("Found #{results["total_hits"]} results:")
for hit <- results["hits"] do
  IO.puts("  - #{hit["doc"]["title"]} (score: #{Float.round(hit["score"], 2)})")
end

# Cleanup
File.rm_rf!(test_path)
IO.puts("\n✅ All fuzzy search tests completed!")
