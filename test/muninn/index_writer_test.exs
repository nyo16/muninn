defmodule Muninn.IndexWriterTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, IndexWriter, Schema}

  setup do
    test_path = "/tmp/muninn_writer_#{:erlang.unique_integer([:positive])}"

    on_exit(fn ->
      File.rm_rf!(test_path)
    end)

    {:ok, test_path: test_path}
  end

  describe "add_document/2" do
    test "adds a text document successfully", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("body", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      doc = %{"title" => "Hello World", "body" => "This is a test document"}
      assert :ok = IndexWriter.add_document(index, doc)
    end

    test "adds numeric fields correctly", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)
        |> Schema.add_u64_field("views", stored: true, indexed: true)
        |> Schema.add_i64_field("score", stored: true, indexed: true)
        |> Schema.add_f64_field("rating", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      doc = %{
        "title" => "Product",
        "views" => 1000,
        "score" => -50,
        "rating" => 4.5
      }

      assert :ok = IndexWriter.add_document(index, doc)
    end

    test "adds boolean fields correctly", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)
        |> Schema.add_bool_field("published", stored: true, indexed: true)
        |> Schema.add_bool_field("featured", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      doc = %{"title" => "Post", "published" => true, "featured" => false}
      assert :ok = IndexWriter.add_document(index, doc)
    end

    test "adds document with all field types", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("name", stored: true, indexed: true)
        |> Schema.add_u64_field("count", stored: true, indexed: true)
        |> Schema.add_i64_field("offset", stored: true, indexed: true)
        |> Schema.add_f64_field("price", stored: true, indexed: true)
        |> Schema.add_bool_field("active", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      doc = %{
        "name" => "Mixed Document",
        "count" => 42,
        "offset" => -10,
        "price" => 19.99,
        "active" => true
      }

      assert :ok = IndexWriter.add_document(index, doc)
    end

    test "handles missing optional fields", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)
        |> Schema.add_text_field("optional", stored: true)

      {:ok, index} = Index.create(test_path, schema)

      # Only provide title, omit optional field
      doc = %{"title" => "Partial Document"}
      assert :ok = IndexWriter.add_document(index, doc)
    end

    test "ignores unknown fields", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)

      {:ok, index} = Index.create(test_path, schema)

      # Include an unknown field
      doc = %{"title" => "Test", "unknown_field" => "ignored"}
      assert :ok = IndexWriter.add_document(index, doc)
    end
  end

  describe "add_documents/2 batch operations" do
    test "adds multiple documents", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_u64_field("views", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      docs = [
        %{"title" => "First", "views" => 10},
        %{"title" => "Second", "views" => 20},
        %{"title" => "Third", "views" => 30}
      ]

      assert :ok = IndexWriter.add_documents(index, docs)
    end

    test "adds many documents efficiently", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true)
        |> Schema.add_u64_field("id", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      docs =
        for i <- 1..100 do
          %{"content" => "Document #{i}", "id" => i}
        end

      assert :ok = IndexWriter.add_documents(index, docs)
    end

    test "adds empty list of documents", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true)
      {:ok, index} = Index.create(test_path, schema)

      assert :ok = IndexWriter.add_documents(index, [])
    end
  end

  describe "commit/1" do
    test "commits documents to make them searchable", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      doc = %{"title" => "Test Document"}
      :ok = IndexWriter.add_document(index, doc)
      assert :ok = IndexWriter.commit(index)

      # Verify index directory has segment files
      assert File.exists?(test_path)
      files = File.ls!(test_path)
      assert length(files) > 0
    end

    test "commit after multiple documents", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("content", stored: true)

      {:ok, index} = Index.create(test_path, schema)

      docs = [
        %{"content" => "First"},
        %{"content" => "Second"},
        %{"content" => "Third"}
      ]

      :ok = IndexWriter.add_documents(index, docs)
      assert :ok = IndexWriter.commit(index)
    end

    test "multiple commits", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true)
      {:ok, index} = Index.create(test_path, schema)

      # First batch
      :ok = IndexWriter.add_document(index, %{"title" => "First"})
      :ok = IndexWriter.commit(index)

      # Second batch
      :ok = IndexWriter.add_document(index, %{"title" => "Second"})
      :ok = IndexWriter.commit(index)

      # Third batch
      :ok = IndexWriter.add_document(index, %{"title" => "Third"})
      :ok = IndexWriter.commit(index)
    end
  end

  describe "rollback/1" do
    test "rolls back uncommitted documents", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true)
      {:ok, index} = Index.create(test_path, schema)

      doc = %{"title" => "Rollback Test"}
      :ok = IndexWriter.add_document(index, doc)
      assert :ok = IndexWriter.rollback(index)
    end

    test "rollback after multiple adds", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("content", stored: true)
      {:ok, index} = Index.create(test_path, schema)

      docs = [
        %{"content" => "First"},
        %{"content" => "Second"},
        %{"content" => "Third"}
      ]

      :ok = IndexWriter.add_documents(index, docs)
      assert :ok = IndexWriter.rollback(index)
    end
  end

  describe "transactions with commit/rollback" do
    test "commit saves, rollback discards", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("title", stored: true)
      {:ok, index} = Index.create(test_path, schema)

      # Add and commit
      :ok = IndexWriter.add_document(index, %{"title" => "Committed"})
      :ok = IndexWriter.commit(index)

      # Add but rollback
      :ok = IndexWriter.add_document(index, %{"title" => "Rolled Back"})
      :ok = IndexWriter.rollback(index)

      # Verify index was created with committed data
      assert File.exists?(test_path)
    end

    test "multiple transaction cycles", %{test_path: test_path} do
      schema = Schema.new() |> Schema.add_text_field("content", stored: true)
      {:ok, index} = Index.create(test_path, schema)

      # Transaction 1: commit
      :ok = IndexWriter.add_document(index, %{"content" => "T1"})
      :ok = IndexWriter.commit(index)

      # Transaction 2: rollback
      :ok = IndexWriter.add_document(index, %{"content" => "T2 rollback"})
      :ok = IndexWriter.rollback(index)

      # Transaction 3: commit
      :ok = IndexWriter.add_document(index, %{"content" => "T3"})
      :ok = IndexWriter.commit(index)
    end
  end

  describe "real-world scenarios" do
    test "e-commerce product indexing", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("name", stored: true, indexed: true)
        |> Schema.add_text_field("description", stored: true, indexed: true)
        |> Schema.add_text_field("sku", stored: true, indexed: false)
        |> Schema.add_f64_field("price", stored: true, indexed: true)
        |> Schema.add_u64_field("stock", stored: true, indexed: true)
        |> Schema.add_bool_field("in_stock", stored: true, indexed: true)
        |> Schema.add_f64_field("rating", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      products = [
        %{
          "name" => "Laptop Pro",
          "description" => "High-performance laptop for professionals",
          "sku" => "LAP-001",
          "price" => 1299.99,
          "stock" => 15,
          "in_stock" => true,
          "rating" => 4.7
        },
        %{
          "name" => "Wireless Mouse",
          "description" => "Ergonomic wireless mouse",
          "sku" => "MOU-042",
          "price" => 29.99,
          "stock" => 0,
          "in_stock" => false,
          "rating" => 4.2
        }
      ]

      :ok = IndexWriter.add_documents(index, products)
      :ok = IndexWriter.commit(index)
    end

    test "blog post indexing", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("content", stored: true, indexed: true)
        |> Schema.add_text_field("author", stored: true, indexed: true)
        |> Schema.add_text_field("tags", stored: true, indexed: true)
        |> Schema.add_u64_field("views", stored: true, indexed: true)
        |> Schema.add_i64_field("likes", stored: true, indexed: true)
        |> Schema.add_bool_field("published", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      posts = [
        %{
          "title" => "Getting Started with Elixir",
          "content" => "Elixir is a dynamic, functional language...",
          "author" => "Jane Doe",
          "tags" => "elixir programming functional",
          "views" => 1523,
          "likes" => 42,
          "published" => true
        },
        %{
          "title" => "Draft Post",
          "content" => "This is not published yet",
          "author" => "John Smith",
          "tags" => "draft",
          "views" => 0,
          "likes" => 0,
          "published" => false
        }
      ]

      :ok = IndexWriter.add_documents(index, posts)
      :ok = IndexWriter.commit(index)
    end

    test "log event indexing with high volume", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("level", stored: true, indexed: true)
        |> Schema.add_text_field("message", stored: true, indexed: true)
        |> Schema.add_u64_field("timestamp", stored: true, indexed: true)
        |> Schema.add_i64_field("response_time", stored: true, indexed: true)

      {:ok, index} = Index.create(test_path, schema)

      # Simulate logging 1000 events
      events =
        for i <- 1..1000 do
          %{
            "level" => Enum.random(["info", "warn", "error"]),
            "message" => "Event #{i}",
            "timestamp" => System.system_time(:second) + i,
            "response_time" => :rand.uniform(1000)
          }
        end

      :ok = IndexWriter.add_documents(index, events)
      :ok = IndexWriter.commit(index)
    end
  end
end
