defmodule Muninn.Index do
  @moduledoc """
  Index management for Muninn search engine.

  An index is a searchable collection of documents. Before creating an index,
  you must define a schema that describes the structure of your documents.

  ## Example

      # Create a schema
      schema = Muninn.Schema.new()
        |> Muninn.Schema.add_text_field("title", stored: true)
        |> Muninn.Schema.add_text_field("body", stored: true)

      # Create an index
      {:ok, index} = Muninn.Index.create("/tmp/my_index", schema)

  """

  alias Muninn.{Native, Schema}

  @type t :: reference()

  @doc """
  Creates a new index at the specified path with the given schema.

  The index directory will be created if it doesn't exist. If the directory
  already contains an index, an error will be returned.

  ## Parameters

    * `path` - The directory path where the index will be stored
    * `schema` - A `Muninn.Schema` defining the index structure

  ## Returns

    * `{:ok, index}` - Successfully created index
    * `{:error, reason}` - Failed to create index

  ## Examples

      schema = Muninn.Schema.new()
        |> Muninn.Schema.add_text_field("title", stored: true)

      {:ok, index} = Muninn.Index.create("/tmp/my_index", schema)

  """
  @spec create(String.t(), Schema.t()) :: {:ok, t()} | {:error, atom()}
  def create(path, %Schema{} = schema) do
    with :ok <- Schema.validate(schema) do
      # Convert schema to list of tuples {name, type, stored, indexed}
      fields = Enum.map(schema.fields, fn field ->
        {field.name, Atom.to_string(field.type), field.stored, field.indexed}
      end)

      Native.index_create(path, fields)
    end
  end

  @doc """
  Opens an existing index at the specified path.

  ## Parameters

    * `path` - The directory path where the index is stored

  ## Returns

    * `{:ok, index}` - Successfully opened index
    * `{:error, reason}` - Failed to open index

  ## Examples

      {:ok, index} = Muninn.Index.open("/tmp/my_index")

  """
  @spec open(String.t()) :: {:ok, t()} | {:error, atom()}
  def open(path) do
    Native.index_open(path)
  end
end
