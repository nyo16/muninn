#!/usr/bin/env elixir

alias Muninn.{Schema, Index, IndexWriter, IndexReader, Searcher}

# Create schema
schema =
  Schema.new()
  |> Schema.add_text_field("title", stored: true, indexed: true)

# Create index
index_path = "/tmp/muninn_prefix_test_#{:erlang.unique_integer([:positive])}"
{:ok, index} = Index.create(index_path, schema)

# Add documents
docs = [
  %{"title" => "Phoenix Framework"},
  %{"title" => "Phone Book"},
  %{"title" => "Photography Tips"},
  %{"title" => "Elixir Programming"},
  %{"title" => "Photoshop Tutorial"}
]

Enum.each(docs, &IndexWriter.add_document(index, &1))
IndexWriter.commit(index)

# Search
{:ok, reader} = IndexReader.new(index)
{:ok, searcher} = Searcher.new(reader)

IO.puts("\nPrefix search for 'pho':")
{:ok, results} = Searcher.search_prefix(searcher, "title", "pho")

IO.puts("Found #{results["total_hits"]} results\n")

for hit <- results["hits"] do
  IO.puts("- #{hit["doc"]["title"]}")
end

# Cleanup
File.rm_rf!(index_path)
