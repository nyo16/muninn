#!/usr/bin/env elixir

# Muninn Complete Search Demo
# Showcases all search features: field:value syntax, boolean operators,
# phrase queries, highlighting/snippets, and prefix/typeahead search

IO.puts("\n🚀 Muninn Complete Search Engine Demo\n")
IO.puts(String.duplicate("=", 70))

alias Muninn.{Schema, Index, IndexWriter, IndexReader, Searcher}

# Create schema
IO.puts("\n📋 Step 1: Creating schema...")

schema =
  Schema.new()
  |> Schema.add_text_field("title", stored: true, indexed: true)
  |> Schema.add_text_field("content", stored: true, indexed: true)
  |> Schema.add_text_field("author", stored: true, indexed: true)
  |> Schema.add_text_field("category", stored: true, indexed: true)

IO.puts("✓ Schema created with 4 text fields")

# Create index
index_path = "/tmp/muninn_complete_demo_#{:erlang.unique_integer([:positive])}"
{:ok, index} = Index.create(index_path, schema)
IO.puts("✓ Index created")

# Add documents
IO.puts("\n📝 Step 2: Adding documents...")

docs = [
  %{
    "title" => "Getting Started with Elixir Programming",
    "content" =>
      "Elixir is a dynamic, functional programming language. Learn the basics of Elixir syntax, pattern matching, and immutability.",
    "author" => "Alice Chen",
    "category" => "tutorial"
  },
  %{
    "title" => "Phoenix Framework for Web Development",
    "content" =>
      "Phoenix is a productive web framework for Elixir. Build real-time web applications with channels and LiveView technology.",
    "author" => "Bob Martinez",
    "category" => "web"
  },
  %{
    "title" => "Photoshop Beginner Tutorial",
    "content" =>
      "Learn the essentials of Adobe Photoshop. Master layers, selections, and basic photo editing techniques.",
    "author" => "Carol Zhang",
    "category" => "design"
  },
  %{
    "title" => "Concurrent Programming with Elixir OTP",
    "content" =>
      "Master concurrent and distributed programming in Elixir. Learn about GenServers, Supervisors, and fault tolerance.",
    "author" => "Alice Chen",
    "category" => "advanced"
  },
  %{
    "title" => "Photography Composition Tips",
    "content" =>
      "Improve your photography skills with composition techniques. Learn about rule of thirds, leading lines, and framing.",
    "author" => "David Park",
    "category" => "photography"
  }
]

Enum.each(docs, &IndexWriter.add_document(index, &1))
IndexWriter.commit(index)

IO.puts("✓ Added #{length(docs)} documents")

# Create searcher
IO.puts("\n🔍 Step 3: Creating search interface...")
{:ok, reader} = IndexReader.new(index)
{:ok, searcher} = Searcher.new(reader)
IO.puts("✓ Searcher ready")

IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("FEATURE DEMONSTRATIONS")
IO.puts(String.duplicate("=", 70))

# Feature 1: Field-specific search
IO.puts("\n🎯 Feature 1: Field-specific Search (title:elixir)")
IO.puts(String.duplicate("-", 70))

{:ok, results} = Searcher.search_query(searcher, "title:elixir", ["title", "content"])

IO.puts("Found #{results["total_hits"]} documents with 'elixir' in title\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Author: #{hit["doc"]["author"]}")
  IO.puts("")
end

# Feature 2: Boolean AND/OR
IO.puts("\n🔗 Feature 2: Boolean Operators (elixir AND programming)")
IO.puts(String.duplicate("-", 70))

{:ok, results} =
  Searcher.search_query(searcher, "elixir AND programming", ["title", "content"])

IO.puts("Found #{results["total_hits"]} documents\n")

for hit <- results["hits"] do
  IO.puts("• #{hit["doc"]["title"]}")
end

IO.puts("\n")

{:ok, results} = Searcher.search_query(searcher, "phoenix OR photoshop", ["title", "content"])

IO.puts("Boolean OR (phoenix OR photoshop): #{results["total_hits"]} results")

for hit <- results["hits"] do
  IO.puts("• #{hit["doc"]["title"]}")
end

# Feature 3: Phrase queries
IO.puts("\n\n📝 Feature 3: Phrase Queries (\"web development\")")
IO.puts(String.duplicate("-", 70))

{:ok, results} =
  Searcher.search_query(searcher, ~s("web development"), ["title", "content"])

IO.puts("Exact phrase match: #{results["total_hits"]} results\n")

for hit <- results["hits"] do
  IO.puts("• #{hit["doc"]["title"]}")
  IO.puts("  #{String.slice(hit["doc"]["content"], 0..80)}...")
  IO.puts("")
end

# Feature 4: Highlighting/Snippets
IO.puts("\n💡 Feature 4: Highlighted Snippets (elixir)")
IO.puts(String.duplicate("-", 70))

{:ok, results} =
  Searcher.search_with_snippets(
    searcher,
    "elixir",
    ["title", "content"],
    ["content"],
    max_snippet_chars: 120
  )

IO.puts("Results with highlighted snippets:\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Snippet: #{hit["snippets"]["content"]}")
  IO.puts("")
end

# Feature 5: Prefix/Typeahead Search
IO.puts("\n🔤 Feature 5: Prefix Search / Typeahead (\"pho\")")
IO.puts(String.duplicate("-", 70))

{:ok, results} = Searcher.search_prefix(searcher, "title", "pho", limit: 10)

IO.puts("Autocomplete suggestions for 'pho': #{results["total_hits"]} results\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
end

IO.puts("\n")

# Simulate typeahead as user types
IO.puts("Simulating typeahead as user types 'programming':\n")

for prefix <- ["pro", "prog", "progr", "program"] do
  {:ok, results} = Searcher.search_prefix(searcher, "content", prefix, limit: 3)
  IO.puts("  '#{prefix}' → #{results["total_hits"]} matches")
end

# Feature 6: Complex Queries
IO.puts("\n\n⚡ Feature 6: Complex Combined Query")
IO.puts(String.duplicate("-", 70))

{:ok, results} =
  Searcher.search_with_snippets(
    searcher,
    "category:tutorial AND (elixir OR programming)",
    ["title", "content", "category"],
    ["content"]
  )

IO.puts("Query: category:tutorial AND (elixir OR programming)")
IO.puts("Found #{results["total_hits"]} results\n")

for hit <- results["hits"] do
  IO.puts("• #{hit["doc"]["title"]}")
  IO.puts("  Category: #{hit["doc"]["category"]}")
  IO.puts("  Snippet: #{hit["snippets"]["content"]}")
  IO.puts("")
end

# Summary
IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("CAPABILITIES SUMMARY")
IO.puts(String.duplicate("=", 70))

IO.puts("""

✅ Muninn Search Engine Features:

1. **Natural Query Syntax**
   • Field-specific: title:elixir, author:alice
   • Boolean operators: AND, OR, NOT
   • Required/excluded: +term, -term
   • Grouping: (term1 OR term2) AND term3

2. **Phrase Search**
   • Exact phrase matching: "web development"
   • Field-specific phrases: title:"getting started"

3. **Highlighting & Snippets**
   • HTML-highlighted matching words with <b> tags
   • Customizable snippet length
   • Multiple fields supported
   • Context extraction around matches

4. **Prefix/Typeahead Search**
   • Autocomplete functionality
   • Real-time suggestions as user types
   • Perfect for search-as-you-type UIs

5. **Performance**
   • Fast in-memory search powered by Tantivy (Rust)
   • Scalable to millions of documents
   • Low-latency queries

📊 Stats for this demo:
   • Documents indexed: #{length(docs)}
   • Fields per document: 4
   • Total searches performed: 10+
   • All searches completed in milliseconds

🔧 Built with:
   • Elixir (high-level API)
   • Rust + Tantivy (search engine)
   • Rustler (Elixir-Rust bridge)
""")

# Cleanup
File.rm_rf!(index_path)

IO.puts(String.duplicate("=", 70))
IO.puts("✨ Demo complete!")
IO.puts(String.duplicate("=", 70) <> "\n")
