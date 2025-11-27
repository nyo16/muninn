#!/usr/bin/env elixir

# Muninn Highlighting & Typeahead Demo
# Demonstrates snippet generation with highlighted matching words
# and prefix/typeahead search functionality

IO.puts("\n✨ Muninn Highlighting & Typeahead Demo\n")
IO.puts(String.duplicate("=", 60))

alias Muninn.{Schema, Index, IndexWriter, IndexReader, Searcher}

# Create schema
IO.puts("\n📋 Creating schema...")

schema =
  Schema.new()
  |> Schema.add_text_field("title", stored: true, indexed: true)
  |> Schema.add_text_field("content", stored: true, indexed: true)
  |> Schema.add_text_field("author", stored: true, indexed: true)

IO.puts("✓ Schema created")

# Create index
index_path = "/tmp/muninn_highlighting_#{:erlang.unique_integer([:positive])}"
{:ok, index} = Index.create(index_path, schema)

# Add documents
IO.puts("\n📝 Adding documents...")

docs = [
  %{
    "title" => "Introduction to Elixir Programming",
    "content" =>
      "Elixir is a dynamic, functional programming language designed for building scalable and maintainable applications. It leverages the Erlang VM, known for running low-latency, distributed, and fault-tolerant systems. Elixir's syntax is heavily influenced by Ruby, making it approachable for developers from various backgrounds.",
    "author" => "Alice Chen"
  },
  %{
    "title" => "Phoenix Framework: Modern Web Development",
    "content" =>
      "Phoenix is a web development framework written in Elixir that patterns itself after other popular web frameworks like Ruby on Rails while also taking advantage of the unique benefits of Elixir. Phoenix uses channels and LiveView to provide real-time features with minimal JavaScript.",
    "author" => "Bob Martinez"
  },
  %{
    "title" => "Ecto: Database Wrapper for Elixir",
    "content" =>
      "Ecto is a database wrapper and integrated query language for Elixir. It provides a standardized API for querying databases, composing queries, and working with database schemas. Ecto supports multiple database engines including PostgreSQL, MySQL, and SQLite.",
    "author" => "Carol Zhang"
  },
  %{
    "title" => "Concurrent Programming with OTP",
    "content" =>
      "OTP (Open Telecom Platform) is a set of libraries and design principles for building concurrent and distributed systems in Elixir and Erlang. GenServers, Supervisors, and Applications form the backbone of fault-tolerant Elixir applications.",
    "author" => "Alice Chen"
  },
  %{
    "title" => "Functional Programming Fundamentals",
    "content" =>
      "Functional programming emphasizes immutability, pure functions, and declarative code. In functional languages like Elixir, data is immutable by default, which eliminates entire classes of bugs related to shared mutable state. Pattern matching and recursion replace traditional looping constructs.",
    "author" => "David Park"
  }
]

Enum.each(docs, &IndexWriter.add_document(index, &1))
IndexWriter.commit(index)

IO.puts("✓ Added #{length(docs)} documents")

# Create searcher
{:ok, reader} = IndexReader.new(index)
{:ok, searcher} = Searcher.new(reader)

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("PART 1: HIGHLIGHTED SNIPPETS")
IO.puts(String.duplicate("=", 60))

# Demo 1: Basic highlighting
IO.puts("\n🔍 Search 1: Basic snippet highlighting (elixir)")
IO.puts(String.duplicate("-", 60))

{:ok, results} =
  Searcher.search_with_snippets(
    searcher,
    "elixir",
    ["title", "content"],
    ["content"]
  )

IO.puts("Found #{results["total_hits"]} results\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Snippet: #{hit["snippets"]["content"]}")
  IO.puts("")
end

# Demo 2: Multi-word highlighting
IO.puts("\n🔍 Search 2: Multi-word highlighting (functional programming)")
IO.puts(String.duplicate("-", 60))

{:ok, results} =
  Searcher.search_with_snippets(
    searcher,
    "functional programming",
    ["title", "content"],
    ["content"]
  )

IO.puts("Found #{results["total_hits"]} results\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Author: #{hit["doc"]["author"]}")
  IO.puts("   Snippet: #{hit["snippets"]["content"]}")
  IO.puts("")
end

# Demo 3: Highlighting in multiple fields
IO.puts("\n🔍 Search 3: Multiple field snippets (phoenix)")
IO.puts(String.duplicate("-", 60))

{:ok, results} =
  Searcher.search_with_snippets(
    searcher,
    "phoenix",
    ["title", "content"],
    ["title", "content"]
  )

IO.puts("Found #{results["total_hits"]} results\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. Title snippet: #{hit["snippets"]["title"]}")
  IO.puts("   Content snippet: #{hit["snippets"]["content"]}")
  IO.puts("")
end

# Demo 4: Custom snippet length
IO.puts("\n🔍 Search 4: Long snippets (database, 300 chars)")
IO.puts(String.duplicate("-", 60))

{:ok, results} =
  Searcher.search_with_snippets(
    searcher,
    "database",
    ["content"],
    ["content"],
    max_snippet_chars: 300
  )

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Extended snippet: #{hit["snippets"]["content"]}")
  IO.puts("")
end

# Demo 5: Boolean query highlighting
IO.puts("\n🔍 Search 5: Boolean query highlighting (elixir AND concurrent)")
IO.puts(String.duplicate("-", 60))

{:ok, results} =
  Searcher.search_with_snippets(
    searcher,
    "elixir AND concurrent",
    ["title", "content"],
    ["content"]
  )

IO.puts("Found #{results["total_hits"]} results\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Snippet: #{hit["snippets"]["content"]}")
  IO.puts("")
end

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("PART 2: TYPEAHEAD / PREFIX SEARCH")
IO.puts(String.duplicate("=", 60))

IO.puts("""

💡 Typeahead uses the wildcard operator (*) at the end of words.
   Examples: "pho*" matches "phoenix", "funct*" matches "functional"
""")

# Demo 6: Simple prefix search
IO.puts("\n🔍 Search 6: Simple typeahead (pho*)")
IO.puts(String.duplicate("-", 60))

{:ok, results} =
  Searcher.search_with_snippets(
    searcher,
    "pho*",
    ["title", "content"],
    ["title", "content"]
  )

IO.puts("Found #{results["total_hits"]} results matching 'pho*'\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Title snippet: #{hit["snippets"]["title"]}")
  IO.puts("   Content snippet: #{hit["snippets"]["content"]}")
  IO.puts("")
end

# Demo 7: Prefix in phrase
IO.puts("\n🔍 Search 7: Prefix in phrase (\"functional prog*\")")
IO.puts(String.duplicate("-", 60))

{:ok, results} =
  Searcher.search_with_snippets(
    searcher,
    ~s("functional prog*"),
    ["content"],
    ["content"]
  )

IO.puts("Found #{results["total_hits"]} results\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Snippet: #{hit["snippets"]["content"]}")
  IO.puts("")
end

# Demo 8: Multiple prefix terms
IO.puts("\n🔍 Search 8: Multiple prefixes (eli* AND conc*)")
IO.puts(String.duplicate("-", 60))

{:ok, results} =
  Searcher.search_with_snippets(
    searcher,
    "eli* AND conc*",
    ["title", "content"],
    ["content"]
  )

IO.puts("Found #{results["total_hits"]} results\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Snippet: #{hit["snippets"]["content"]}")
  IO.puts("")
end

# Demo 9: Field-specific prefix
IO.puts("\n🔍 Search 9: Field-specific prefix (title:func*)")
IO.puts(String.duplicate("-", 60))

{:ok, results} =
  Searcher.search_with_snippets(
    searcher,
    "title:func*",
    ["title", "content"],
    ["title"]
  )

IO.puts("Found #{results["total_hits"]} results\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. Title: #{hit["doc"]["title"]}")
  IO.puts("   Highlighted: #{hit["snippets"]["title"]}")
  IO.puts("")
end

# Demo 10: Autocomplete simulation
IO.puts("\n🔍 Search 10: Autocomplete simulation")
IO.puts(String.duplicate("-", 60))

prefixes = ["el*", "eli*", "elix*", "elixir"]

IO.puts("Simulating user typing 'elixir' character by character:\n")

for prefix <- prefixes do
  {:ok, results} = Searcher.search_query(searcher, prefix, ["title", "content"], limit: 3)

  IO.puts("Query: '#{prefix}' → #{results["total_hits"]} results")

  for hit <- Enum.take(results["hits"], 2) do
    IO.puts("  - #{hit["doc"]["title"]}")
  end

  IO.puts("")
end

# Summary
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("FEATURE SUMMARY")
IO.puts(String.duplicate("=", 60))

IO.puts("""

✨ Snippet/Highlighting Features:
   • Matching words wrapped in <b> HTML tags
   • Customizable snippet length (default: 150 chars)
   • Multiple fields can have snippets
   • Works with all query types (term, boolean, phrase)
   • Intelligent context extraction around matches

🔤 Typeahead/Prefix Search Features:
   • Use * wildcard for prefix matching: "pho*" → "phoenix"
   • Works in phrases: "functional prog*"
   • Field-specific: "title:eli*"
   • Boolean combinations: "eli* AND prog*"
   • Perfect for autocomplete functionality

📝 Use Cases:
   • Search result previews with highlighted keywords
   • Autocomplete dropdowns as users type
   • "Did you mean" suggestions
   • Related content discovery
   • Real-time search feedback
""")

# Cleanup
File.rm_rf!(index_path)

IO.puts(String.duplicate("=", 60))
IO.puts("✨ Demo completed!")
IO.puts(String.duplicate("=", 60) <> "\n")
