#!/usr/bin/env elixir

# Test if QueryParser already supports range syntax

alias Muninn.{Schema, Index, IndexWriter, IndexReader, Searcher}

# Create schema with numeric fields
schema =
  Schema.new()
  |> Schema.add_text_field("title", stored: true, indexed: true)
  |> Schema.add_u64_field("views", stored: true, indexed: true)
  |> Schema.add_f64_field("price", stored: true, indexed: true)
  |> Schema.add_i64_field("temperature", stored: true, indexed: true)

index_path = "/tmp/muninn_range_test_#{:erlang.unique_integer([:positive])}"
{:ok, index} = Index.create(index_path, schema)

# Add test documents
docs = [
  %{"title" => "Low views", "views" => 50, "price" => 9.99, "temperature" => -10},
  %{"title" => "Medium views", "views" => 500, "price" => 49.99, "temperature" => 0},
  %{"title" => "High views", "views" => 5000, "price" => 99.99, "temperature" => 20},
  %{"title" => "Very high views", "views" => 10000, "price" => 199.99, "temperature" => 30}
]

Enum.each(docs, &IndexWriter.add_document(index, &1))
IndexWriter.commit(index)

{:ok, reader} = IndexReader.new(index)
{:ok, searcher} = Searcher.new(reader)

IO.puts("\nTesting Range Query Syntax:\n")

# Test 1: U64 range (inclusive)
IO.puts("1. U64 inclusive range views:[100 TO 1000]")
case Searcher.search_query(searcher, "views:[100 TO 1000]", ["title"]) do
  {:ok, results} ->
    IO.puts("   Found #{results["total_hits"]} results")
    for hit <- results["hits"], do: IO.puts("   - #{hit["doc"]["title"]} (#{hit["doc"]["views"]} views)")
  {:error, reason} ->
    IO.puts("   ERROR: #{reason}")
end

# Test 2: F64 range
IO.puts("\n2. F64 range price:[10.0 TO 100.0]")
case Searcher.search_query(searcher, "price:[10.0 TO 100.0]", ["title"]) do
  {:ok, results} ->
    IO.puts("   Found #{results["total_hits"]} results")
    for hit <- results["hits"], do: IO.puts("   - #{hit["doc"]["title"]} ($#{hit["doc"]["price"]})")
  {:error, reason} ->
    IO.puts("   ERROR: #{reason}")
end

# Test 3: I64 range
IO.puts("\n3. I64 range temperature:[-5 TO 25]")
case Searcher.search_query(searcher, "temperature:[-5 TO 25]", ["title"]) do
  {:ok, results} ->
    IO.puts("   Found #{results["total_hits"]} results")
    for hit <- results["hits"], do: IO.puts("   - #{hit["doc"]["title"]} (#{hit["doc"]["temperature"]}°C)")
  {:error, reason} ->
    IO.puts("   ERROR: #{reason}")
end

# Test 4: Open-ended range
IO.puts("\n4. Open-ended range views:[1000 TO *]")
case Searcher.search_query(searcher, "views:[1000 TO *]", ["title"]) do
  {:ok, results} ->
    IO.puts("   Found #{results["total_hits"]} results")
    for hit <- results["hits"], do: IO.puts("   - #{hit["doc"]["title"]} (#{hit["doc"]["views"]} views)")
  {:error, reason} ->
    IO.puts("   ERROR: #{reason}")
end

# Cleanup
File.rm_rf!(index_path)
IO.puts("\nTest complete.")
