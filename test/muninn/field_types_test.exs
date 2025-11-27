defmodule Muninn.FieldTypesTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, Schema}

  setup do
    test_path = "/tmp/muninn_field_types_#{:erlang.unique_integer([:positive])}"

    on_exit(fn ->
      Muninn.TestHelpers.safe_rm_rf(test_path)
    end)

    {:ok, test_path: test_path}
  end

  describe "text fields" do
    test "creates index with text fields", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("body", stored: true, indexed: true)
        |> Schema.add_text_field("metadata", stored: true, indexed: false)

      assert {:ok, _index} = Index.create(test_path, schema)
      assert {:ok, _index} = Index.open(test_path)
    end
  end

  describe "numeric fields - u64" do
    test "creates index with u64 fields", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)
        |> Schema.add_u64_field("count", stored: true, indexed: true)
        |> Schema.add_u64_field("views", stored: false, indexed: true)

      assert {:ok, _index} = Index.create(test_path, schema)
      assert {:ok, _index} = Index.open(test_path)
    end

    test "u64 field has correct type" do
      schema = Schema.new() |> Schema.add_u64_field("count")
      field = hd(schema.fields)

      assert field.type == :u64
      assert field.name == "count"
    end
  end

  describe "numeric fields - i64" do
    test "creates index with i64 fields", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)
        |> Schema.add_i64_field("temperature", stored: true, indexed: true)
        |> Schema.add_i64_field("offset", stored: true, indexed: false)

      assert {:ok, _index} = Index.create(test_path, schema)
      assert {:ok, _index} = Index.open(test_path)
    end

    test "i64 field has correct type" do
      schema = Schema.new() |> Schema.add_i64_field("temperature")
      field = hd(schema.fields)

      assert field.type == :i64
      assert field.name == "temperature"
    end
  end

  describe "numeric fields - f64" do
    test "creates index with f64 fields", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("product", stored: true)
        |> Schema.add_f64_field("price", stored: true, indexed: true)
        |> Schema.add_f64_field("rating", stored: true, indexed: true)

      assert {:ok, _index} = Index.create(test_path, schema)
      assert {:ok, _index} = Index.open(test_path)
    end

    test "f64 field has correct type" do
      schema = Schema.new() |> Schema.add_f64_field("price")
      field = hd(schema.fields)

      assert field.type == :f64
      assert field.name == "price"
    end
  end

  describe "boolean fields" do
    test "creates index with bool fields", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)
        |> Schema.add_bool_field("published", stored: true, indexed: true)
        |> Schema.add_bool_field("featured", stored: false, indexed: true)

      assert {:ok, _index} = Index.create(test_path, schema)
      assert {:ok, _index} = Index.open(test_path)
    end

    test "bool field has correct type" do
      schema = Schema.new() |> Schema.add_bool_field("published")
      field = hd(schema.fields)

      assert field.type == :bool
      assert field.name == "published"
    end
  end

  describe "mixed field types" do
    test "creates index with all supported field types", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("body", stored: true, indexed: true)
        |> Schema.add_u64_field("view_count", stored: true, indexed: true)
        |> Schema.add_i64_field("score", stored: true, indexed: true)
        |> Schema.add_f64_field("price", stored: true, indexed: true)
        |> Schema.add_bool_field("published", stored: true, indexed: true)

      assert length(schema.fields) == 6
      assert {:ok, _index} = Index.create(test_path, schema)
      assert {:ok, _index} = Index.open(test_path)
    end

    test "e-commerce product schema", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("name", stored: true, indexed: true)
        |> Schema.add_text_field("description", stored: true, indexed: true)
        |> Schema.add_text_field("sku", stored: true, indexed: false)
        |> Schema.add_f64_field("price", stored: true, indexed: true)
        |> Schema.add_u64_field("stock_quantity", stored: true, indexed: true)
        |> Schema.add_bool_field("in_stock", stored: true, indexed: true)
        |> Schema.add_bool_field("featured", stored: false, indexed: true)
        |> Schema.add_f64_field("rating", stored: true, indexed: true)
        |> Schema.add_u64_field("review_count", stored: true, indexed: false)

      assert {:ok, _index} = Index.create(test_path, schema)
      assert {:ok, _index} = Index.open(test_path)
    end

    test "blog post schema", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("content", stored: true, indexed: true)
        |> Schema.add_text_field("author", stored: true, indexed: true)
        |> Schema.add_text_field("tags", stored: true, indexed: true)
        |> Schema.add_u64_field("view_count", stored: true, indexed: true)
        |> Schema.add_i64_field("likes", stored: true, indexed: true)
        |> Schema.add_bool_field("published", stored: true, indexed: true)
        |> Schema.add_bool_field("featured", stored: true, indexed: true)

      assert {:ok, _index} = Index.create(test_path, schema)
      assert {:ok, _index} = Index.open(test_path)
    end

    test "analytics event schema", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("event_name", stored: true, indexed: true)
        |> Schema.add_text_field("user_id", stored: true, indexed: false)
        |> Schema.add_text_field("session_id", stored: true, indexed: false)
        |> Schema.add_u64_field("timestamp", stored: true, indexed: true)
        |> Schema.add_f64_field("duration_ms", stored: true, indexed: true)
        |> Schema.add_i64_field("value", stored: true, indexed: true)
        |> Schema.add_bool_field("conversion", stored: true, indexed: true)

      assert {:ok, _index} = Index.create(test_path, schema)
      assert {:ok, _index} = Index.open(test_path)
    end
  end

  describe "field type validation" do
    test "all field types convert to map correctly" do
      schema =
        Schema.new()
        |> Schema.add_text_field("text_field")
        |> Schema.add_u64_field("u64_field")
        |> Schema.add_i64_field("i64_field")
        |> Schema.add_f64_field("f64_field")
        |> Schema.add_bool_field("bool_field")

      map = Schema.to_map(schema)

      types = Enum.map(map.fields, & &1.type)

      assert "text" in types
      assert "u64" in types
      assert "i64" in types
      assert "f64" in types
      assert "bool" in types
    end

    test "numeric fields with different options", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_u64_field("stored_only", stored: true, indexed: false)
        |> Schema.add_u64_field("indexed_only", stored: false, indexed: true)
        |> Schema.add_u64_field("both", stored: true, indexed: true)
        |> Schema.add_u64_field("neither", stored: false, indexed: false)

      assert {:ok, _index} = Index.create(test_path, schema)
    end
  end

  describe "large schemas with many field types" do
    test "handles schema with 50+ fields of mixed types", %{test_path: test_path} do
      schema =
        Enum.reduce(1..20, Schema.new(), fn i, acc ->
          acc
          |> Schema.add_text_field("text_#{i}", stored: rem(i, 2) == 0)
          |> Schema.add_u64_field("count_#{i}", stored: rem(i, 3) == 0)
          |> Schema.add_bool_field("flag_#{i}", stored: rem(i, 5) == 0)
        end)

      assert length(schema.fields) == 60
      assert {:ok, _index} = Index.create(test_path, schema)
      assert {:ok, _index} = Index.open(test_path)
    end
  end
end
