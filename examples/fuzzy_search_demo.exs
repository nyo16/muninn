#!/usr/bin/env elixir

# Comprehensive fuzzy search demonstration
# Usage: mix run examples/fuzzy_search_demo.exs

alias Muninn.{Index, IndexWriter, IndexReader, Searcher, Schema}

# Create test index with blog posts
test_path = "/tmp/muninn_fuzzy_demo"
File.rm_rf!(test_path)

IO.puts("=" <> String.duplicate("=", 70))
IO.puts("Muninn Fuzzy Search Demo")
IO.puts("=" <> String.duplicate("=", 70))

# Setup index with sample data
schema = Schema.new()
  |> Schema.add_text_field("title", stored: true, indexed: true)
  |> Schema.add_text_field("content", stored: true, indexed: true)
  |> Schema.add_text_field("author", stored: true, indexed: true)
  |> Schema.add_u64_field("views", stored: true, indexed: true)

{:ok, index} = Index.create(test_path, schema)

IO.puts("\n📚 Indexing sample documents...")

# Index sample documents with common programming topics
documents = [
  %{
    "title" => "Getting Started with Elixir",
    "content" => "Learn the basics of Elixir programming language. Elixir is a functional, concurrent language built on the Erlang VM.",
    "author" => "José Valim",
    "views" => 1500
  },
  %{
    "title" => "Phoenix Framework Guide",
    "content" => "Build modern web applications with Phoenix. Phoenix leverages the power of Elixir for real-time features.",
    "author" => "Chris McCord",
    "views" => 2000
  },
  %{
    "title" => "Programming in Erlang",
    "content" => "Master Erlang fundamentals and concurrent programming patterns. Erlang is the foundation of Elixir.",
    "author" => "Joe Armstrong",
    "views" => 800
  },
  %{
    "title" => "Elixir Pattern Matching",
    "content" => "Deep dive into Elixir's powerful pattern matching capabilities. Pattern matching is at the heart of Elixir.",
    "author" => "Dave Thomas",
    "views" => 1200
  },
  %{
    "title" => "Functional Programming Concepts",
    "content" => "Explore functional programming principles with practical examples. Learn immutability, recursion, and higher-order functions.",
    "author" => "José Valim",
    "views" => 950
  }
]

Enum.each(documents, &IndexWriter.add_document(index, &1))
IndexWriter.commit(index)

{:ok, reader} = IndexReader.new(index)
{:ok, searcher} = Searcher.new(reader)

IO.puts("✓ Indexed #{length(documents)} documents\n")

# Demo 1: Basic fuzzy search with typos
IO.puts("=" <> String.duplicate("=", 70))
IO.puts("Demo 1: Basic Fuzzy Search - Handling Typos")
IO.puts("=" <> String.duplicate("=", 70))
IO.puts("\n🔍 Searching for 'elixr' (typo for 'elixir') with distance=1...\n")

{:ok, results} = Searcher.search_fuzzy(searcher, "title", "elixr", distance: 1)
IO.puts("Found #{results["total_hits"]} results:")
for hit <- results["hits"] do
  IO.puts("  📄 #{hit["doc"]["title"]}")
  IO.puts("     Author: #{hit["doc"]["author"]} | Views: #{hit["doc"]["views"]} | Score: #{Float.round(hit["score"], 2)}")
end

# Demo 2: Character transposition
IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("Demo 2: Character Transposition")
IO.puts(String.duplicate("=", 70))
IO.puts("\n🔍 Searching for 'phoneix' (transposed characters) with distance=1...\n")

{:ok, results} = Searcher.search_fuzzy(searcher, "title", "phoneix", distance: 1)
IO.puts("Found #{results["total_hits"]} results:")
for hit <- results["hits"] do
  IO.puts("  📄 #{hit["doc"]["title"]}")
end

# Demo 3: Distance=2 search (more tolerant)
IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("Demo 3: Higher Distance - More Tolerant Search")
IO.puts(String.duplicate("=", 70))
IO.puts("\n🔍 Searching for 'progamming' (2 typos) with distance=2...\n")

{:ok, results} = Searcher.search_fuzzy(searcher, "content", "progamming", distance: 2)
IO.puts("Found #{results["total_hits"]} results:")
for hit <- results["hits"] do
  IO.puts("  📄 #{hit["doc"]["title"]}")
end

# Demo 4: Fuzzy prefix (autocomplete with typos)
IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("Demo 4: Fuzzy Prefix Search - Autocomplete with Typo Tolerance")
IO.puts(String.duplicate("=", 70))
IO.puts("\n🔍 Searching for prefix 'pho' with distance=1 (matches 'phoenix')...\n")

{:ok, results} = Searcher.search_fuzzy_prefix(searcher, "title", "pho", distance: 1, limit: 5)
IO.puts("Found #{results["total_hits"]} results:")
for hit <- results["hits"] do
  IO.puts("  📄 #{hit["doc"]["title"]}")
end

# Demo 5: Fuzzy with snippets
IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("Demo 5: Fuzzy Search with Highlighted Snippets")
IO.puts(String.duplicate("=", 70))
IO.puts("\n🔍 Searching for 'elixr' with context snippets...\n")

{:ok, results} = Searcher.search_fuzzy_with_snippets(
  searcher,
  "content",
  "elixr",
  ["content"],
  distance: 1,
  max_snippet_chars: 150,
  limit: 3
)

IO.puts("Found #{results["total_hits"]} results with snippets:")
for hit <- results["hits"] do
  IO.puts("\n  📄 #{hit["doc"]["title"]}")
  IO.puts("     Author: #{hit["doc"]["author"]}")
  if snippet = hit["snippets"]["content"] do
    IO.puts("     💬 \"#{snippet}\"")
  end
end

# Demo 6: Transposition cost comparison
IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("Demo 6: Transposition Cost - True vs False")
IO.puts(String.duplicate("=", 70))
IO.puts("\n🔍 Searching for 'erlnag' (transposed 'n' and 'a')...\n")

IO.puts("With transposition_cost_one=true (transposition counts as 1 edit):")
{:ok, results1} = Searcher.search_fuzzy(
  searcher,
  "title",
  "erlnag",
  distance: 1,
  transposition: true
)
IO.puts("  Found #{results1["total_hits"]} results")

IO.puts("\nWith transposition_cost_one=false (transposition counts as 2 edits):")
{:ok, results2} = Searcher.search_fuzzy(
  searcher,
  "title",
  "erlnag",
  distance: 1,
  transposition: false
)
IO.puts("  Found #{results2["total_hits"]} results")

# Demo 7: Real-world use case - Author search
IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("Demo 7: Real-World Use Case - Author Search with Typos")
IO.puts(String.duplicate("=", 70))
IO.puts("\n🔍 User types 'jose' (looking for 'José')...\n")

{:ok, results} = Searcher.search_fuzzy(searcher, "author", "jose", distance: 1)
IO.puts("Found #{results["total_hits"]} document(s) by this author:")
for hit <- results["hits"] do
  IO.puts("  📄 #{hit["doc"]["title"]} by #{hit["doc"]["author"]}")
end

# Demo 8: Performance comparison
IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("Demo 8: Performance Comparison - Distance=1 vs Distance=2")
IO.puts(String.duplicate("=", 70))

IO.puts("\n⏱️  Measuring search performance...\n")

# Distance=1
{time1, {:ok, _}} = :timer.tc(fn ->
  Searcher.search_fuzzy(searcher, "content", "programming", distance: 1)
end)

# Distance=2
{time2, {:ok, _}} = :timer.tc(fn ->
  Searcher.search_fuzzy(searcher, "content", "programming", distance: 2)
end)

IO.puts("Distance=1: #{time1 / 1000} ms")
IO.puts("Distance=2: #{time2 / 1000} ms")
IO.puts("Ratio: #{Float.round(time2 / time1, 2)}x slower")

IO.puts("\n💡 Recommendation: Use distance=1 for real-time search, distance=2 for suggestions")

# Cleanup
File.rm_rf!(test_path)

IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("✅ Fuzzy Search Demo Complete!")
IO.puts(String.duplicate("=", 70))

IO.puts("\n📚 Key Takeaways:")
IO.puts("  • Distance=1: Handles ~90% of common typos, good performance")
IO.puts("  • Distance=2: Handles ~99% of typos, slower (use for suggestions)")
IO.puts("  • Transposition=true: Character swaps count as 1 edit (recommended)")
IO.puts("  • Fuzzy prefix: Great for autocomplete with typo tolerance")
IO.puts("  • Snippets: Shows context around fuzzy matches")
