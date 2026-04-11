# Aggregation, Sorting, and Analytics Demo
#
# Run with: mix run examples/aggregation_demo.exs

alias Muninn.{Schema, Index, IndexWriter, IndexReader, Searcher}
alias Muninn.Aggregation
alias Muninn.Aggregation.{Bucket, Metric}

# --- Setup: Create index with fast fields ---

path = "/tmp/muninn_agg_demo_#{:erlang.unique_integer([:positive])}"

schema =
  Schema.new()
  |> Schema.add_text_field("title", stored: true, tokenizer: "en_stem")
  |> Schema.add_text_field("category", stored: true, tokenizer: "raw", fast: true)
  |> Schema.add_f64_field("price", stored: true, fast: true)
  |> Schema.add_u64_field("quantity", stored: true, fast: true)
  |> Schema.add_u64_field("rating", stored: true, fast: true)

{:ok, index} = Index.create(path, schema)

# Index sample products
products = [
  %{
    "title" => "MacBook Pro",
    "category" => "electronics",
    "price" => 2499.0,
    "quantity" => 10,
    "rating" => 5
  },
  %{
    "title" => "iPhone 15",
    "category" => "electronics",
    "price" => 999.0,
    "quantity" => 50,
    "rating" => 4
  },
  %{
    "title" => "AirPods Pro",
    "category" => "electronics",
    "price" => 249.0,
    "quantity" => 200,
    "rating" => 4
  },
  %{
    "title" => "iPad Air",
    "category" => "electronics",
    "price" => 599.0,
    "quantity" => 30,
    "rating" => 5
  },
  %{
    "title" => "Running Shoes",
    "category" => "sports",
    "price" => 129.0,
    "quantity" => 100,
    "rating" => 4
  },
  %{
    "title" => "Yoga Mat",
    "category" => "sports",
    "price" => 29.0,
    "quantity" => 500,
    "rating" => 3
  },
  %{
    "title" => "Tennis Racket",
    "category" => "sports",
    "price" => 199.0,
    "quantity" => 40,
    "rating" => 4
  },
  %{
    "title" => "Water Bottle",
    "category" => "sports",
    "price" => 15.0,
    "quantity" => 1000,
    "rating" => 3
  },
  %{
    "title" => "Elixir in Action",
    "category" => "books",
    "price" => 45.0,
    "quantity" => 300,
    "rating" => 5
  },
  %{
    "title" => "Programming Phoenix",
    "category" => "books",
    "price" => 40.0,
    "quantity" => 250,
    "rating" => 5
  },
  %{
    "title" => "The Pragmatic Programmer",
    "category" => "books",
    "price" => 50.0,
    "quantity" => 400,
    "rating" => 5
  },
  %{
    "title" => "Clean Code",
    "category" => "books",
    "price" => 35.0,
    "quantity" => 350,
    "rating" => 4
  }
]

Enum.each(products, &IndexWriter.add_document(index, &1))
IndexWriter.commit(index)

{:ok, reader} = IndexReader.new(index)
{:ok, searcher} = Searcher.new(reader)

IO.puts("=== Muninn Aggregation & Analytics Demo ===\n")
IO.puts("Indexed #{length(products)} products across 3 categories\n")

# --- 1. Count ---
IO.puts("--- 1. Count Queries ---")
{:ok, total} = Searcher.count(searcher, "*", ["title"])
{:ok, electronics} = Searcher.count(searcher, "category:electronics", ["title", "category"])
{:ok, books} = Searcher.count(searcher, "category:books", ["title", "category"])
IO.puts("Total products: #{total}")
IO.puts("Electronics: #{electronics}")
IO.puts("Books: #{books}\n")

# --- 2. Sort by field ---
IO.puts("--- 2. Sort by Price (descending) ---")

{:ok, results} =
  Searcher.search_query_sorted(searcher, "*", ["title"], "price", reverse: true, limit: 5)

for hit <- results["hits"] do
  IO.puts("  $#{hit["doc"]["price"]} - #{hit["doc"]["title"]}")
end

IO.puts("")

# --- 3. Stats aggregation ---
IO.puts("--- 3. Price Statistics ---")
aggs = Aggregation.new() |> Aggregation.add("price_stats", Metric.stats("price"))
{:ok, results} = Searcher.aggregate(searcher, "*", ["title"], aggs)
stats = results["price_stats"]
IO.puts("  Count: #{stats["count"]}")
IO.puts("  Min:   $#{stats["min"]}")
IO.puts("  Max:   $#{stats["max"]}")
IO.puts("  Avg:   $#{Float.round(stats["avg"], 2)}")
IO.puts("  Sum:   $#{stats["sum"]}\n")

# --- 4. Terms aggregation ---
IO.puts("--- 4. Products by Category ---")
aggs = Aggregation.new() |> Aggregation.add("by_category", Bucket.terms("category", size: 10))
{:ok, results} = Searcher.aggregate(searcher, "*", ["title"], aggs)

for bucket <- results["by_category"]["buckets"] do
  IO.puts("  #{bucket["key"]}: #{bucket["doc_count"]} products")
end

IO.puts("")

# --- 5. Nested aggregation ---
IO.puts("--- 5. Average Price per Category ---")

aggs =
  Aggregation.new()
  |> Aggregation.add(
    "by_category",
    Bucket.terms("category", size: 10)
    |> Aggregation.sub("avg_price", Metric.avg("price"))
  )

{:ok, results} = Searcher.aggregate(searcher, "*", ["title"], aggs)

for bucket <- results["by_category"]["buckets"] do
  avg = Float.round(bucket["avg_price"]["value"], 2)
  IO.puts("  #{bucket["key"]}: $#{avg} avg (#{bucket["doc_count"]} items)")
end

IO.puts("")

# --- 6. Range aggregation ---
IO.puts("--- 6. Price Range Distribution ---")

aggs =
  Aggregation.new()
  |> Aggregation.add(
    "price_ranges",
    Bucket.range("price", [
      %{"key" => "budget", "to" => 50.0},
      %{"key" => "mid-range", "from" => 50.0, "to" => 500.0},
      %{"key" => "premium", "from" => 500.0}
    ])
  )

{:ok, results} = Searcher.aggregate(searcher, "*", ["title"], aggs)

for bucket <- results["price_ranges"]["buckets"] do
  IO.puts("  #{bucket["key"]}: #{bucket["doc_count"]} products")
end

IO.puts("")

# --- 7. Regex search ---
IO.puts("--- 7. Regex Search (titles matching 'pro.*') ---")
{:ok, results} = Searcher.search_regex(searcher, "title", "pro.*", limit: 10)

for hit <- results["hits"] do
  IO.puts("  #{hit["doc"]["title"]}")
end

IO.puts("")

# --- 8. MoreLikeThis ---
IO.puts("--- 8. MoreLikeThis (similar to 'programming books') ---")

{:ok, results} =
  Searcher.search_more_like_this(
    searcher,
    %{"title" => "programming elixir phoenix books"},
    min_doc_freq: 1,
    min_term_freq: 1,
    limit: 5
  )

IO.puts("  Found #{results["total_hits"]} similar documents:")

for hit <- results["hits"] do
  IO.puts("  - #{hit["doc"]["title"]} (score: #{Float.round(hit["score"], 2)})")
end

IO.puts("")

# Cleanup
File.rm_rf!(path)
IO.puts("Done! (cleaned up temp index)")
