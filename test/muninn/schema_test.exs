defmodule Muninn.SchemaTest do
  use ExUnit.Case, async: true

  alias Muninn.Schema

  describe "new/0" do
    test "creates an empty schema" do
      schema = Schema.new()
      assert schema.fields == []
    end
  end

  describe "add_text_field/3" do
    test "adds a text field to the schema" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title")

      assert length(schema.fields) == 1
      assert hd(schema.fields).name == "title"
      assert hd(schema.fields).type == :text
    end

    test "adds multiple text fields" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title")
        |> Schema.add_text_field("body")

      assert length(schema.fields) == 2
    end

    test "respects stored option" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)

      assert hd(schema.fields).stored == true
    end

    test "respects indexed option" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", indexed: false)

      assert hd(schema.fields).indexed == false
    end

    test "defaults to not stored and indexed" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title")

      assert hd(schema.fields).stored == false
      assert hd(schema.fields).indexed == true
    end
  end

  describe "validate/1" do
    test "returns :ok for valid schema" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title")

      assert Schema.validate(schema) == :ok
    end

    test "returns error for empty schema" do
      schema = Schema.new()

      assert Schema.validate(schema) == {:error, :no_fields}
    end

    test "returns error for duplicate field names" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title")
        |> Schema.add_text_field("title")

      assert Schema.validate(schema) == {:error, :duplicate_field_names}
    end
  end

  describe "to_map/1" do
    test "converts schema to map" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)

      map = Schema.to_map(schema)

      assert is_map(map)
      assert is_list(map.fields)
      assert length(map.fields) == 1

      field = hd(map.fields)
      assert field.name == "title"
      assert field.type == "text"
      assert field.stored == true
    end
  end
end
