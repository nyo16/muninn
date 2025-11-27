defmodule Muninn.IndexTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, Schema}

  @test_index_path "/tmp/muninn_test_#{:erlang.unique_integer([:positive])}"

  setup do
    # Clean up test index before each test
    File.rm_rf!(@test_index_path)

    on_exit(fn ->
      File.rm_rf!(@test_index_path)
    end)

    :ok
  end

  describe "create/2" do
    test "creates a new index with valid schema" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)
        |> Schema.add_text_field("body", stored: true)

      assert {:ok, index} = Index.create(@test_index_path, schema)
      assert is_reference(index)

      # Verify index directory was created
      assert File.exists?(@test_index_path)
      assert File.dir?(@test_index_path)
    end

    test "returns error for invalid schema" do
      schema = Schema.new()

      assert {:error, :no_fields} = Index.create(@test_index_path, schema)
    end

    test "returns error for duplicate field names" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title")
        |> Schema.add_text_field("title")

      assert {:error, :duplicate_field_names} = Index.create(@test_index_path, schema)
    end
  end

  describe "open/1" do
    test "opens an existing index" do
      # First create an index
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)

      {:ok, _index} = Index.create(@test_index_path, schema)

      # Now open it
      assert {:ok, index} = Index.open(@test_index_path)
      assert is_reference(index)
    end

    test "returns error for non-existent index" do
      assert {:error, _reason} = Index.open("/tmp/nonexistent_index_#{:erlang.unique_integer()}")
    end
  end
end
