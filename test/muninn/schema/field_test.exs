defmodule Muninn.Schema.FieldTest do
  use ExUnit.Case, async: true

  alias Muninn.Schema.Field

  describe "new/3" do
    test "creates a text field with defaults" do
      field = Field.new(:text, "title")

      assert field.type == :text
      assert field.name == "title"
      assert field.stored == false
      assert field.indexed == true
    end

    test "creates a field with stored option" do
      field = Field.new(:text, "content", stored: true)

      assert field.stored == true
    end

    test "creates a field with indexed option" do
      field = Field.new(:text, "meta", indexed: false)

      assert field.indexed == false
    end

    test "creates a field with both options" do
      field = Field.new(:text, "body", stored: true, indexed: true)

      assert field.stored == true
      assert field.indexed == true
    end

    test "supports different field types" do
      text_field = Field.new(:text, "title")
      u64_field = Field.new(:u64, "count")
      bool_field = Field.new(:bool, "active")

      assert text_field.type == :text
      assert u64_field.type == :u64
      assert bool_field.type == :bool
    end
  end

  describe "to_map/1" do
    test "converts field to map with correct keys" do
      field = Field.new(:text, "title", stored: true, indexed: true)
      map = Field.to_map(field)

      assert map.name == "title"
      assert map.type == "text"
      assert map.stored == true
      assert map.indexed == true
    end

    test "converts field type atom to string" do
      field = Field.new(:text, "content")
      map = Field.to_map(field)

      assert is_binary(map.type)
      assert map.type == "text"
    end

    test "preserves boolean values" do
      field = Field.new(:text, "meta", stored: false, indexed: false)
      map = Field.to_map(field)

      assert map.stored === false
      assert map.indexed === false
    end
  end
end
