defmodule Muninn.IntegrationTest do
  use ExUnit.Case, async: true

  alias Muninn.{Index, Schema}

  setup do
    # Create unique test directory for each test
    test_path = "/tmp/muninn_integration_#{:erlang.unique_integer([:positive])}"

    on_exit(fn ->
      File.rm_rf!(test_path)
    end)

    {:ok, test_path: test_path}
  end

  describe "full workflow: schema -> index -> open" do
    test "can create schema, create index, and reopen it", %{test_path: test_path} do
      # Step 1: Create schema
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)
        |> Schema.add_text_field("body", stored: true)
        |> Schema.add_text_field("tags")

      assert Schema.validate(schema) == :ok

      # Step 2: Create index
      assert {:ok, index1} = Index.create(test_path, schema)
      assert is_reference(index1)

      # Step 3: Verify index directory structure
      assert File.exists?(test_path)
      assert File.dir?(test_path)

      # Tantivy creates a meta.json file
      assert File.exists?(Path.join(test_path, "meta.json"))

      # Step 4: Reopen the index
      assert {:ok, index2} = Index.open(test_path)
      assert is_reference(index2)

      # Ensure they are different references (not cached)
      assert index1 != index2
    end

    test "multiple indexes in different directories work independently", %{test_path: _test_path} do
      schema1 =
        Schema.new()
        |> Schema.add_text_field("field1", stored: true)

      schema2 =
        Schema.new()
        |> Schema.add_text_field("field2", stored: true)
        |> Schema.add_text_field("field3")

      path1 = "/tmp/muninn_multi_1_#{:erlang.unique_integer([:positive])}"
      path2 = "/tmp/muninn_multi_2_#{:erlang.unique_integer([:positive])}"

      on_exit(fn ->
        File.rm_rf!(path1)
        File.rm_rf!(path2)
      end)

      # Create two different indexes
      assert {:ok, _index1} = Index.create(path1, schema1)
      assert {:ok, _index2} = Index.create(path2, schema2)

      # Both should exist
      assert File.exists?(path1)
      assert File.exists?(path2)

      # Both can be reopened
      assert {:ok, _} = Index.open(path1)
      assert {:ok, _} = Index.open(path2)
    end
  end

  describe "error handling" do
    test "creating index with invalid schema fails early", %{test_path: test_path} do
      empty_schema = Schema.new()

      assert {:error, :no_fields} = Index.create(test_path, empty_schema)

      # Verify no directory was created
      refute File.exists?(test_path)
    end

    test "creating index with duplicate fields fails early", %{test_path: test_path} do
      bad_schema =
        Schema.new()
        |> Schema.add_text_field("duplicate")
        |> Schema.add_text_field("duplicate")

      assert {:error, :duplicate_field_names} = Index.create(test_path, bad_schema)

      # Verify no directory was created
      refute File.exists?(test_path)
    end

    test "opening non-existent index returns error" do
      fake_path = "/tmp/muninn_nonexist_#{:erlang.unique_integer([:positive])}"

      assert {:error, reason} = Index.open(fake_path)
      assert is_binary(reason)
      assert reason =~ "Failed to open index"
    end

    test "creating index in read-only location fails gracefully" do
      # Try to create in /dev/null or similar (platform specific)
      readonly_path = "/dev/null/muninn_test"

      schema =
        Schema.new()
        |> Schema.add_text_field("field")

      assert {:error, reason} = Index.create(readonly_path, schema)
      assert is_binary(reason)
    end
  end

  describe "schema variations" do
    test "schema with only stored fields", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("metadata", stored: true, indexed: false)

      assert {:ok, _index} = Index.create(test_path, schema)
      assert {:ok, _index} = Index.open(test_path)
    end

    test "schema with only indexed (not stored) fields", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("searchable", stored: false, indexed: true)

      assert {:ok, _index} = Index.create(test_path, schema)
      assert {:ok, _index} = Index.open(test_path)
    end

    test "schema with mix of stored and indexed fields", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true, indexed: true)
        |> Schema.add_text_field("content", stored: false, indexed: true)
        |> Schema.add_text_field("metadata", stored: true, indexed: false)

      assert {:ok, _index} = Index.create(test_path, schema)
      assert {:ok, _index} = Index.open(test_path)
    end

    test "schema with many fields", %{test_path: test_path} do
      schema =
        Enum.reduce(1..20, Schema.new(), fn i, acc ->
          Schema.add_text_field(acc, "field_#{i}", stored: rem(i, 2) == 0)
        end)

      assert length(schema.fields) == 20
      assert {:ok, _index} = Index.create(test_path, schema)
      assert {:ok, _index} = Index.open(test_path)
    end
  end

  describe "concurrent operations" do
    test "can open same index from multiple processes", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)

      # Create the index first
      assert {:ok, _} = Index.create(test_path, schema)

      # Open it from multiple processes concurrently
      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            Index.open(test_path)
          end)
        end

      results = Task.await_many(tasks)

      # All should succeed
      assert Enum.all?(results, fn result ->
               match?({:ok, _}, result)
             end)
    end

    test "can create multiple indexes concurrently", %{test_path: _test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("field", stored: true)

      paths =
        for i <- 1..5 do
          "/tmp/muninn_concurrent_#{i}_#{:erlang.unique_integer([:positive])}"
        end

      on_exit(fn ->
        Enum.each(paths, &File.rm_rf!/1)
      end)

      tasks =
        for path <- paths do
          Task.async(fn ->
            Index.create(path, schema)
          end)
        end

      results = Task.await_many(tasks)

      # All should succeed
      assert Enum.all?(results, fn result ->
               match?({:ok, _}, result)
             end)

      # All directories should exist
      assert Enum.all?(paths, &File.exists?/1)
    end
  end

  describe "edge cases" do
    test "field names with special characters", %{test_path: test_path} do
      schema =
        Schema.new()
        |> Schema.add_text_field("field_with_underscores", stored: true)
        |> Schema.add_text_field("field-with-dashes", stored: true)
        |> Schema.add_text_field("field123", stored: true)

      assert {:ok, _index} = Index.create(test_path, schema)
      assert {:ok, _index} = Index.open(test_path)
    end

    test "long field names", %{test_path: test_path} do
      long_name = String.duplicate("a", 100)

      schema =
        Schema.new()
        |> Schema.add_text_field(long_name, stored: true)

      assert {:ok, _index} = Index.create(test_path, schema)
      assert {:ok, _index} = Index.open(test_path)
    end

    test "path with nested directories", %{test_path: _test_path} do
      nested_path = "/tmp/muninn_#{:erlang.unique_integer([:positive])}/nested/deep/index"

      on_exit(fn ->
        File.rm_rf!(Path.dirname(Path.dirname(Path.dirname(nested_path))))
      end)

      schema =
        Schema.new()
        |> Schema.add_text_field("field", stored: true)

      assert {:ok, _index} = Index.create(nested_path, schema)
      assert File.exists?(nested_path)
      assert {:ok, _index} = Index.open(nested_path)
    end
  end
end
