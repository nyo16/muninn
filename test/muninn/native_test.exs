defmodule Muninn.NativeTest do
  use ExUnit.Case, async: true

  alias Muninn.{Native, Schema}

  describe "schema_build/1" do
    test "builds a schema from field list" do
      fields = [
        {"title", "text", true, true},
        {"body", "text", true, false}
      ]

      schema_resource = Native.schema_build(fields)
      assert is_reference(schema_resource)
    end

    test "builds empty schema" do
      fields = []

      schema_resource = Native.schema_build(fields)
      assert is_reference(schema_resource)
    end
  end

  describe "schema_num_fields/1" do
    test "returns number of fields in schema" do
      fields = [
        {"field1", "text", true, true},
        {"field2", "text", false, true}
      ]

      schema = Native.schema_build(fields)
      assert Native.schema_num_fields(schema) == 2
    end

    test "returns 0 for empty schema" do
      fields = []

      schema = Native.schema_build(fields)
      assert Native.schema_num_fields(schema) == 0
    end

    test "counts many fields correctly" do
      fields =
        for i <- 1..10 do
          {"field_#{i}", "text", true, true}
        end

      schema = Native.schema_build(fields)
      assert Native.schema_num_fields(schema) == 10
    end
  end

  describe "index_create/2" do
    test "creates index with schema" do
      path = "/tmp/muninn_native_test_#{:erlang.unique_integer([:positive])}"

      on_exit(fn -> File.rm_rf!(path) end)

      fields = [{"title", "text", true, true}]

      assert {:ok, index} = Native.index_create(path, fields)
      assert is_reference(index)
    end
  end

  describe "index_open/1" do
    test "opens existing index" do
      path = "/tmp/muninn_native_open_#{:erlang.unique_integer([:positive])}"

      on_exit(fn -> File.rm_rf!(path) end)

      # Create first
      fields = [{"field", "text", true, true}]
      {:ok, _} = Native.index_create(path, fields)

      # Then open
      assert {:ok, index} = Native.index_open(path)
      assert is_reference(index)
    end

    test "returns error for non-existent index" do
      path = "/tmp/muninn_nonexist_#{:erlang.unique_integer([:positive])}"

      assert {:error, reason} = Native.index_open(path)
      assert is_binary(reason)
    end
  end
end
