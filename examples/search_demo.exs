#!/usr/bin/env elixir

# Muninn Search Engine - End-to-End Demo
# This script demonstrates the complete workflow of creating an index,
# adding documents, and searching them.

IO.puts("\n🔍 Muninn Search Engine Demo\n")
IO.puts(String.duplicate("=", 60))

alias Muninn.{Schema, Index, IndexWriter, IndexReader, Searcher, Query}

# Step 1: Create a schema for a blog
IO.puts("\n📋 Step 1: Creating schema for blog posts...")

schema =
  Schema.new()
  |> Schema.add_text_field("title", stored: true, indexed: true)
  |> Schema.add_text_field("content", stored: true, indexed: true)
  |> Schema.add_text_field("author", stored: true, indexed: true)
  |> Schema.add_text_field("tags", stored: true, indexed: true)
  |> Schema.add_u64_field("views", stored: true, indexed: false)
  |> Schema.add_bool_field("published", stored: true, indexed: false)

IO.puts("✓ Schema created with 6 fields")

# Step 2: Create the index
IO.puts("\n📂 Step 2: Creating index...")

index_path = "/tmp/muninn_demo_#{:erlang.unique_integer([:positive])}"
{:ok, index} = Index.create(index_path, schema)

IO.puts("✓ Index created at: #{index_path}")

# Step 3: Add documents
IO.puts("\n📝 Step 3: Adding blog posts...")

posts = [
  %{
    "title" => "Getting Started with Elixir",
    "content" => "Elixir is a dynamic, functional language designed for building scalable applications. It runs on the Erlang VM and provides excellent concurrency support.",
    "author" => "Alice Chen",
    "tags" => "elixir programming tutorial beginner",
    "views" => 1523,
    "published" => true
  },
  %{
    "title" => "Advanced Elixir Patterns",
    "content" => "Learn advanced patterns in Elixir including GenServers, Supervisors, and OTP principles. Master the art of fault-tolerant systems.",
    "author" => "Bob Martinez",
    "tags" => "elixir advanced otp genserver",
    "views" => 892,
    "published" => true
  },
  %{
    "title" => "Building Search Engines with Rust",
    "content" => "Rust provides excellent performance for building search engines. Learn how to use Tantivy, a full-text search library written in Rust.",
    "author" => "Carol Zhang",
    "tags" => "rust search tantivy performance",
    "views" => 2104,
    "published" => true
  },
  %{
    "title" => "Elixir Phoenix Framework Deep Dive",
    "content" => "Phoenix is a web framework for Elixir that provides high performance and real-time features. Build modern web applications with ease.",
    "author" => "Alice Chen",
    "tags" => "elixir phoenix web framework",
    "views" => 3421,
    "published" => true
  },
  %{
    "title" => "Introduction to Functional Programming",
    "content" => "Functional programming is a paradigm that treats computation as evaluation of functions. Learn the core concepts with practical examples.",
    "author" => "David Park",
    "tags" => "functional programming concepts theory",
    "views" => 1876,
    "published" => true
  },
  %{
    "title" => "Draft: Upcoming Elixir 2.0 Features",
    "content" => "This is a draft post about potential features in Elixir 2.0. Not yet published.",
    "author" => "Bob Martinez",
    "tags" => "elixir draft future",
    "views" => 42,
    "published" => false
  }
]

# Add documents one by one (you can also use add_documents for batch)
Enum.each(posts, fn post ->
  :ok = IndexWriter.add_document(index, post)
end)

IO.puts("✓ Added #{length(posts)} blog posts")

# Step 4: Commit the changes
IO.puts("\n💾 Step 4: Committing changes to index...")

:ok = IndexWriter.commit(index)

IO.puts("✓ All changes committed and searchable")

# Step 5: Create reader and searcher
IO.puts("\n🔍 Step 5: Creating search interface...")

{:ok, reader} = IndexReader.new(index)
{:ok, searcher} = Searcher.new(reader)

IO.puts("✓ Reader and searcher ready")

# Step 6: Perform searches
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("SEARCH DEMONSTRATIONS")
IO.puts(String.duplicate("=", 60))

# Search 1: Find all posts about "elixir"
IO.puts("\n🔎 Search 1: Posts about 'elixir'")
IO.puts(String.duplicate("-", 60))

query1 = Query.term("title", "elixir")
{:ok, results1} = Searcher.search(searcher, query1, limit: 10)

IO.puts("Found #{results1["total_hits"]} posts\n")

for {hit, idx} <- Enum.with_index(results1["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Author: #{hit["doc"]["author"]}")
  IO.puts("   Views: #{hit["doc"]["views"]}")
  IO.puts("   Score: #{Float.round(hit["score"], 3)}")
  IO.puts("")
end

# Search 2: Find posts about "rust"
IO.puts("\n🔎 Search 2: Posts about 'rust'")
IO.puts(String.duplicate("-", 60))

query2 = Query.term("content", "rust")
{:ok, results2} = Searcher.search(searcher, query2, limit: 10)

IO.puts("Found #{results2["total_hits"]} posts\n")

for {hit, idx} <- Enum.with_index(results2["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Preview: #{String.slice(hit["doc"]["content"], 0..100)}...")
  IO.puts("   Score: #{Float.round(hit["score"], 3)}")
  IO.puts("")
end

# Search 3: Find posts by tag "programming"
IO.puts("\n🔎 Search 3: Posts tagged with 'programming'")
IO.puts(String.duplicate("-", 60))

query3 = Query.term("tags", "programming")
{:ok, results3} = Searcher.search(searcher, query3, limit: 10)

IO.puts("Found #{results3["total_hits"]} posts\n")

for {hit, idx} <- Enum.with_index(results3["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Tags: #{hit["doc"]["tags"]}")
  IO.puts("   Score: #{Float.round(hit["score"], 3)}")
  IO.puts("")
end

# Search 4: Find posts by author "Alice Chen"
IO.puts("\n🔎 Search 4: Posts by 'alice'")
IO.puts(String.duplicate("-", 60))

query4 = Query.term("author", "alice")
{:ok, results4} = Searcher.search(searcher, query4, limit: 10)

IO.puts("Found #{results4["total_hits"]} posts\n")

for {hit, idx} <- Enum.with_index(results4["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Author: #{hit["doc"]["author"]}")
  IO.puts("   Published: #{hit["doc"]["published"]}")
  IO.puts("")
end

# Search 5: Demonstrate limit parameter
IO.puts("\n🔎 Search 5: Top 2 posts about 'elixir' (with limit)")
IO.puts(String.duplicate("-", 60))

query5 = Query.term("tags", "elixir")
{:ok, results5} = Searcher.search(searcher, query5, limit: 2)

IO.puts("Showing #{length(results5["hits"])} of #{results5["total_hits"]} results\n")

for {hit, idx} <- Enum.with_index(results5["hits"], 1) do
  IO.puts("#{idx}. #{hit["doc"]["title"]}")
  IO.puts("   Views: #{hit["doc"]["views"]}")
  IO.puts("")
end

# Search 6: Search with no results
IO.puts("\n🔎 Search 6: Posts about 'javascript' (no matches)")
IO.puts(String.duplicate("-", 60))

query6 = Query.term("content", "javascript")
{:ok, results6} = Searcher.search(searcher, query6, limit: 10)

IO.puts("Found #{results6["total_hits"]} posts")

if results6["total_hits"] == 0 do
  IO.puts("No posts found matching 'javascript'\n")
end

# Statistics
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("STATISTICS")
IO.puts(String.duplicate("=", 60))

IO.puts("\n📊 Index Statistics:")
IO.puts("   Total documents indexed: #{length(posts)}")
IO.puts("   Published documents: #{Enum.count(posts, & &1["published"])}")
IO.puts("   Draft documents: #{Enum.count(posts, &(!&1["published"]))}")
IO.puts("   Total authors: #{posts |> Enum.map(& &1["author"]) |> Enum.uniq() |> length()}")
IO.puts("   Total views: #{Enum.sum(Enum.map(posts, & &1["views"]))}")

IO.puts("\n🔍 Search Results Summary:")
IO.puts("   Posts about 'elixir': #{results1["total_hits"]}")
IO.puts("   Posts about 'rust': #{results2["total_hits"]}")
IO.puts("   Posts tagged 'programming': #{results3["total_hits"]}")
IO.puts("   Posts by 'alice': #{results4["total_hits"]}")

# Cleanup
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("🧹 Cleanup: Removing temporary index...")
File.rm_rf!(index_path)
IO.puts("✓ Cleanup complete")

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("✨ Demo completed successfully!")
IO.puts(String.duplicate("=", 60) <> "\n")

IO.puts("""
💡 Key Takeaways:
   • Schema defines the structure of your documents
   • Documents are maps with field names as keys
   • Commit makes documents searchable
   • Term queries search for individual tokens in fields
   • Results include relevance scores
   • Only stored fields are returned in results
   • Case-insensitive search via tokenization
""")
