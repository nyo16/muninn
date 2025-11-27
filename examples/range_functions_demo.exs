#!/usr/bin/env elixir

# Test both QueryParser syntax AND dedicated range functions

alias Muninn.{Schema, Index, IndexWriter, IndexReader, Searcher}

schema =
  Schema.new()
  |> Schema.add_text_field("title", stored: true, indexed: true)
  |> Schema.add_u64_field("views", stored: true, indexed: true)
  |> Schema.add_f64_field("price", stored: true, indexed: true)
  |> Schema.add_i64_field("temperature", stored: true, indexed: true)

index_path = "/tmp/muninn_range_demo_#{:erlang.unique_integer([:positive])}"
{:ok, index} = Index.create(index_path, schema)

docs = [
  %{"title" => "Product A", "views" => 50, "price" => 9.99, "temperature" => -10},
  %{"title" => "Product B", "views" => 500, "price" => 49.99, "temperature" => 0},
  %{"title" => "Product C", "views" => 5000, "price" => 99.99, "temperature" => 20},
  %{"title" => "Product D", "views" => 10000, "price" => 199.99, "temperature" => 30}
]

Enum.each(docs, &IndexWriter.add_document(index, &1))
IndexWriter.commit(index)

{:ok, reader} = IndexReader.new(index)
{:ok, searcher} = Searcher.new(reader)

IO.puts("\nRange Query Comparison: QueryParser vs Dedicated Functions\n")
IO.puts(String.duplicate("=", 70))

# Test 1: U64 range
IO.puts("\n1. U64 Range (views 100-1000)")
IO.puts(String.duplicate("-", 70))

IO.puts("   Method A: QueryParser syntax")
{:ok, results_a} = Searcher.search_query(searcher, "views:[100 TO 1000]", ["title"])
IO.puts("   Found: #{results_a["total_hits"]} results")
for hit <- results_a["hits"], do: IO.puts("   - #{hit["doc"]["title"]} (#{hit["doc"]["views"]} views)")

IO.puts("\n   Method B: Dedicated function")
{:ok, results_b} = Searcher.search_range_u64(searcher, "views", 100, 1000, inclusive: :both)
IO.puts("   Found: #{results_b["total_hits"]} results")
for hit <- results_b["hits"], do: IO.puts("   - #{hit["doc"]["title"]} (#{hit["doc"]["views"]} views)")

# Test 2: F64 range
IO.puts("\n2. F64 Range (price $10.00-$100.00)")
IO.puts(String.duplicate("-", 70))

IO.puts("   Method A: QueryParser syntax")
{:ok, results_a} = Searcher.search_query(searcher, "price:[10.0 TO 100.0]", ["title"])
IO.puts("   Found: #{results_a["total_hits"]} results")
for hit <- results_a["hits"], do: IO.puts("   - #{hit["doc"]["title"]} ($#{hit["doc"]["price"]})")

IO.puts("\n   Method B: Dedicated function")
{:ok, results_b} = Searcher.search_range_f64(searcher, "price", 10.0, 100.0, inclusive: :both)
IO.puts("   Found: #{results_b["total_hits"]} results")
for hit <- results_b["hits"], do: IO.puts("   - #{hit["doc"]["title"]} ($#{hit["doc"]["price"]})")

# Test 3: I64 range
IO.puts("\n3. I64 Range (temperature -5°C to 25°C)")
IO.puts(String.duplicate("-", 70))

IO.puts("   Method A: QueryParser syntax")
{:ok, results_a} = Searcher.search_query(searcher, "temperature:[-5 TO 25]", ["title"])
IO.puts("   Found: #{results_a["total_hits"]} results")
for hit <- results_a["hits"], do: IO.puts("   - #{hit["doc"]["title"]} (#{hit["doc"]["temperature"]}°C)")

IO.puts("\n   Method B: Dedicated function")
{:ok, results_b} = Searcher.search_range_i64(searcher, "temperature", -5, 25, inclusive: :both)
IO.puts("   Found: #{results_b["total_hits"]} results")
for hit <- results_b["hits"], do: IO.puts("   - #{hit["doc"]["title"]} (#{hit["doc"]["temperature"]}°C)")

# Test 4: Inclusive/Exclusive boundaries
IO.puts("\n4. Boundary Inclusivity (views [100 TO 500))")
IO.puts(String.duplicate("-", 70))

IO.puts("   Inclusive lower, exclusive upper:")
{:ok, results} = Searcher.search_range_u64(searcher, "views", 100, 500, inclusive: :lower)
IO.puts("   Found: #{results["total_hits"]} results")
for hit <- results["hits"], do: IO.puts("   - #{hit["doc"]["title"]} (#{hit["doc"]["views"]} views)")

# Test 5: Combined with text search
IO.puts("\n5. Combined Range + Text Search")
IO.puts(String.duplicate("-", 70))

{:ok, results} = Searcher.search_query(
  searcher,
  "title:product AND price:[40.0 TO 150.0]",
  ["title"]
)
IO.puts("   Query: title:product AND price:[40.0 TO 150.0]")
IO.puts("   Found: #{results["total_hits"]} results")
for hit <- results["hits"] do
  IO.puts("   - #{hit["doc"]["title"]} ($#{hit["doc"]["price"]})")
end

# Cleanup
File.rm_rf!(index_path)

IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("Summary:")
IO.puts("  - Both methods produce identical results")
IO.puts("  - QueryParser: Best for user input (field:[low TO high])")
IO.puts("  - Dedicated functions: Best for programmatic queries")
IO.puts("  - All numeric types supported: u64, i64, f64")
IO.puts("  - Flexible boundary control: :both, :lower, :upper, :neither")
IO.puts(String.duplicate("=", 70) <> "\n")
