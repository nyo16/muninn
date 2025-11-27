#!/usr/bin/env elixir

# Muninn Advanced Search Demo
# Demonstrates the powerful query parser with field:value syntax,
# boolean operators (AND/OR), phrase queries, and more!

IO.puts("\n🔍 Muninn Advanced Search Demo\n")
IO.puts(String.duplicate("=", 60))

alias Muninn.{Schema, Index, IndexWriter, IndexReader, Searcher}

# Create a schema for a tech blog
IO.puts("\n📋 Creating schema for tech blog...")

schema =
  Schema.new()
  |> Schema.add_text_field("title", stored: true, indexed: true)
  |> Schema.add_text_field("content", stored: true, indexed: true)
  |> Schema.add_text_field("author", stored: true, indexed: true)
  |> Schema.add_text_field("category", stored: true, indexed: true)
  |> Schema.add_text_field("tags", stored: true, indexed: true)
  |> Schema.add_u64_field("views", stored: true, indexed: false)
  |> Schema.add_bool_field("published", stored: true, indexed: false)

IO.puts("✓ Schema created")

# Create index
IO.puts("\n📂 Creating index...")
index_path = "/tmp/muninn_advanced_demo_#{:erlang.unique_integer([:positive])}"
{:ok, index} = Index.create(index_path, schema)
IO.puts("✓ Index created at: #{index_path}")

# Add blog posts
IO.puts("\n📝 Adding blog posts...")

posts = [
  %{
    "title" => "Getting Started with Elixir",
    "content" =>
      "Elixir is a dynamic, functional programming language designed for building scalable and maintainable applications. It runs on the Erlang VM and provides excellent concurrency support through lightweight processes.",
    "author" => "Alice Chen",
    "category" => "tutorial",
    "tags" => "elixir beginner tutorial programming",
    "views" => 1523,
    "published" => true
  },
  %{
    "title" => "Phoenix Framework Deep Dive",
    "content" =>
      "Phoenix is a web framework for Elixir that provides high performance and real-time features. Learn how to build modern web applications with Phoenix channels and LiveView.",
    "author" => "Alice Chen",
    "category" => "web development",
    "tags" => "elixir phoenix web framework",
    "views" => 3421,
    "published" => true
  },
  %{
    "title" => "Building Search Engines with Rust and Tantivy",
    "content" =>
      "Rust provides excellent performance for building search engines. Tantivy is a full-text search engine library written in Rust, similar to Apache Lucene but with Rust's memory safety guarantees.",
    "author" => "Bob Martinez",
    "category" => "tutorial",
    "tags" => "rust search tantivy performance",
    "views" => 2104,
    "published" => true
  },
  %{
    "title" => "Concurrent Programming with Elixir OTP",
    "content" =>
      "Learn advanced patterns in Elixir including GenServers, Supervisors, and OTP principles. Master the art of building fault-tolerant distributed systems with Elixir.",
    "author" => "Carol Zhang",
    "category" => "advanced",
    "tags" => "elixir otp concurrent genserver advanced",
    "views" => 892,
    "published" => true
  },
  %{
    "title" => "Introduction to Functional Programming",
    "content" =>
      "Functional programming is a programming paradigm that treats computation as the evaluation of mathematical functions. Learn core concepts like immutability, pure functions, and higher-order functions.",
    "author" => "David Park",
    "category" => "concepts",
    "tags" => "functional programming theory concepts",
    "views" => 1876,
    "published" => true
  },
  %{
    "title" => "Web Development Best Practices",
    "content" =>
      "Modern web development requires understanding of many concepts: responsive design, accessibility, security, and performance optimization. This guide covers essential best practices.",
    "author" => "Alice Chen",
    "category" => "web development",
    "tags" => "web development best practices",
    "views" => 2543,
    "published" => true
  },
  %{
    "title" => "Draft: Upcoming Elixir Features",
    "content" =>
      "This is a draft post about potential features coming in future Elixir releases. Not yet ready for publication.",
    "author" => "Bob Martinez",
    "category" => "news",
    "tags" => "elixir draft future",
    "views" => 42,
    "published" => false
  },
  %{
    "title" => "Rust for Systems Programming",
    "content" =>
      "Rust is ideal for systems programming due to its zero-cost abstractions, memory safety without garbage collection, and fearless concurrency. Learn how to build high-performance systems.",
    "author" => "Carol Zhang",
    "category" => "systems",
    "tags" => "rust systems programming performance",
    "views" => 1654,
    "published" => true
  }
]

Enum.each(posts, fn post ->
  :ok = IndexWriter.add_document(index, post)
end)

IO.puts("✓ Added #{length(posts)} blog posts")

# Commit changes
IO.puts("\n💾 Committing changes...")
:ok = IndexWriter.commit(index)
IO.puts("✓ All changes committed")

# Create reader and searcher
IO.puts("\n🔍 Creating search interface...")
{:ok, reader} = IndexReader.new(index)
{:ok, searcher} = Searcher.new(reader)
IO.puts("✓ Ready to search!")

# Demo searches
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("ADVANCED SEARCH DEMONSTRATIONS")
IO.puts(String.duplicate("=", 60))

# Search 1: Field-specific search
IO.puts("\n🔎 Search 1: Field-specific search (title:elixir)")
IO.puts(String.duplicate("-", 60))

{:ok, results} = Searcher.search_query(searcher, "title:elixir", ["title", "content"])

IO.puts("Found #{results["total_hits"]} posts with 'elixir' in the title\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Author: #{hit["doc"]["author"]}")
  IO.puts("   Score: #{Float.round(hit["score"], 3)}")
  IO.puts("")
end

# Search 2: Boolean AND
IO.puts("\n🔎 Search 2: Boolean AND (elixir AND web)")
IO.puts(String.duplicate("-", 60))

{:ok, results} = Searcher.search_query(searcher, "elixir AND web", ["title", "content"])

IO.puts("Found #{results["total_hits"]} posts with both 'elixir' AND 'web'\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Category: #{hit["doc"]["category"]}")
  IO.puts("   Score: #{Float.round(hit["score"], 3)}")
  IO.puts("")
end

# Search 3: Boolean OR
IO.puts("\n🔎 Search 3: Boolean OR (rust OR elixir)")
IO.puts(String.duplicate("-", 60))

{:ok, results} = Searcher.search_query(searcher, "rust OR elixir", ["title", "content"])

IO.puts("Found #{results["total_hits"]} posts about 'rust' OR 'elixir'\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Author: #{hit["doc"]["author"]}")
  IO.puts("   Views: #{hit["doc"]["views"]}")
  IO.puts("")
end

# Search 4: Phrase query
IO.puts("\n🔎 Search 4: Phrase query (\"functional programming\")")
IO.puts(String.duplicate("-", 60))

{:ok, results} =
  Searcher.search_query(searcher, ~s("functional programming"), ["title", "content"])

IO.puts("Found #{results["total_hits"]} posts with exact phrase 'functional programming'\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Preview: #{String.slice(hit["doc"]["content"], 0..80)}...")
  IO.puts("")
end

# Search 5: Required and excluded terms
IO.puts("\n🔎 Search 5: Required/Excluded (+elixir -draft)")
IO.puts(String.duplicate("-", 60))

{:ok, results} = Searcher.search_query(searcher, "+elixir -draft", ["title", "content", "tags"])

IO.puts("Found #{results["total_hits"]} posts with 'elixir' but NOT 'draft'\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Published: #{hit["doc"]["published"]}")
  IO.puts("")
end

# Search 6: Field-specific with author
IO.puts("\n🔎 Search 6: Field-specific author (author:alice)")
IO.puts(String.duplicate("-", 60))

{:ok, results} = Searcher.search_query(searcher, "author:alice", ["title", "content"])

IO.puts("Found #{results["total_hits"]} posts by Alice\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Category: #{hit["doc"]["category"]}")
  IO.puts("   Views: #{hit["doc"]["views"]}")
  IO.puts("")
end

# Search 7: Complex query with parentheses
IO.puts("\n🔎 Search 7: Complex query (title:elixir AND (web OR concurrent))")
IO.puts(String.duplicate("-", 60))

{:ok, results} =
  Searcher.search_query(searcher, "title:elixir AND (web OR concurrent)", ["title", "content"])

IO.puts("Found #{results["total_hits"]} posts\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Tags: #{hit["doc"]["tags"]}")
  IO.puts("")
end

# Search 8: Category-specific with boolean
IO.puts("\n🔎 Search 8: Category search (category:tutorial AND (elixir OR rust))")
IO.puts(String.duplicate("-", 60))

{:ok, results} =
  Searcher.search_query(
    searcher,
    "category:tutorial AND (elixir OR rust)",
    ["title", "content", "category"]
  )

IO.puts("Found #{results["total_hits"]} tutorials about elixir or rust\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Author: #{hit["doc"]["author"]}")
  IO.puts("")
end

# Search 9: Phrase in specific field
IO.puts("\n🔎 Search 9: Phrase in field (title:\"web development\")")
IO.puts(String.duplicate("-", 60))

{:ok, results} =
  Searcher.search_query(searcher, ~s(title:"web development"), ["title", "content"])

IO.puts("Found #{results["total_hits"]} posts\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Content: #{String.slice(hit["doc"]["content"], 0..100)}...")
  IO.puts("")
end

# Search 10: Multi-field complex query
IO.puts("\n🔎 Search 10: Ultra complex query")
IO.puts("Query: (title:elixir OR title:rust) AND category:tutorial AND -draft")
IO.puts(String.duplicate("-", 60))

{:ok, results} =
  Searcher.search_query(
    searcher,
    "(title:elixir OR title:rust) AND category:tutorial AND -draft",
    ["title", "content", "category"]
  )

IO.puts("Found #{results["total_hits"]} results\n")

for {hit, idx} <- Enum.with_index(results["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Category: #{hit["doc"]["category"]}")
  IO.puts("   Author: #{hit["doc"]["author"]}")
  IO.puts("   Published: #{hit["doc"]["published"]}")
  IO.puts("")
end

# Statistics
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("QUERY SYNTAX REFERENCE")
IO.puts(String.duplicate("=", 60))

IO.puts("""

📚 Supported Query Syntax:

1. Field-specific search:
   • title:elixir          - Search for "elixir" in title field
   • author:alice          - Search for "alice" in author field

2. Boolean operators:
   • elixir AND phoenix    - Both terms must be present
   • rust OR go            - Either term must be present
   • NOT draft             - Exclude term

3. Required/Excluded:
   • +elixir phoenix       - "elixir" required, "phoenix" optional
   • elixir -draft         - Include "elixir", exclude "draft"

4. Phrase queries:
   • "functional programming"        - Exact phrase match
   • title:"web development"         - Phrase in specific field

5. Grouping with parentheses:
   • (elixir OR rust) AND tutorial   - Group OR conditions
   • title:(web OR mobile)           - Multiple values for field

6. Complex combinations:
   • title:elixir AND (content:web OR content:otp) -draft
   • (category:tutorial OR category:guide) AND published:true
   • author:alice AND "best practices" AND -draft

💡 Tips:
   • Queries are case-insensitive
   • AND has higher precedence than OR
   • Use parentheses to control precedence
   • Combine field-specific searches with boolean operators
   • Default fields are searched when no field is specified
""")

# Cleanup
IO.puts(String.duplicate("=", 60))
IO.puts("🧹 Cleanup: Removing temporary index...")
File.rm_rf!(index_path)
IO.puts("✓ Cleanup complete")

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("✨ Demo completed successfully!")
IO.puts(String.duplicate("=", 60) <> "\n")
