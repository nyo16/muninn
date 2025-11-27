defmodule Muninn.Schema do
  @moduledoc """
  Schema definition for Muninn search indices.

  A schema defines the structure of documents in an index, including field names,
  types, and indexing options.

  ## Example

      schema = Muninn.Schema.new()
        |> Muninn.Schema.add_text_field("title", stored: true)
        |> Muninn.Schema.add_text_field("body", stored: true)

  """

  alias Muninn.Schema.Field

  @type t :: %__MODULE__{
          fields: [Field.t()]
        }

  defstruct fields: []

  @doc """
  Creates a new empty schema.

  ## Examples

      iex> schema = Muninn.Schema.new()
      iex> schema.fields
      []

  """
  @spec new() :: t()
  def new do
    %__MODULE__{fields: []}
  end

  @doc """
  Adds a text field to the schema.

  ## Options

    * `:stored` - Whether to store the field value (default: `false`)
    * `:indexed` - Whether to index the field for searching (default: `true`)

  ## Examples

      iex> schema = Muninn.Schema.new()
      iex> schema = Muninn.Schema.add_text_field(schema, "title", stored: true)
      iex> length(schema.fields)
      1

  """
  @spec add_text_field(t(), String.t(), keyword()) :: t()
  def add_text_field(%__MODULE__{fields: fields} = schema, name, opts \\ []) do
    field = Field.new(:text, name, opts)
    %{schema | fields: fields ++ [field]}
  end

  @doc """
  Adds an unsigned 64-bit integer field to the schema.

  ## Options

    * `:stored` - Whether to store the field value (default: `false`)
    * `:indexed` - Whether to index the field (default: `true`)

  ## Examples

      iex> schema = Muninn.Schema.new()
      iex> schema = Muninn.Schema.add_u64_field(schema, "count", stored: true)
      iex> hd(schema.fields).type
      :u64

  """
  @spec add_u64_field(t(), String.t(), keyword()) :: t()
  def add_u64_field(%__MODULE__{fields: fields} = schema, name, opts \\ []) do
    field = Field.new(:u64, name, opts)
    %{schema | fields: fields ++ [field]}
  end

  @doc """
  Adds a signed 64-bit integer field to the schema.

  ## Options

    * `:stored` - Whether to store the field value (default: `false`)
    * `:indexed` - Whether to index the field (default: `true`)

  ## Examples

      iex> schema = Muninn.Schema.new()
      iex> schema = Muninn.Schema.add_i64_field(schema, "temperature", stored: true)
      iex> hd(schema.fields).type
      :i64

  """
  @spec add_i64_field(t(), String.t(), keyword()) :: t()
  def add_i64_field(%__MODULE__{fields: fields} = schema, name, opts \\ []) do
    field = Field.new(:i64, name, opts)
    %{schema | fields: fields ++ [field]}
  end

  @doc """
  Adds a 64-bit floating point field to the schema.

  ## Options

    * `:stored` - Whether to store the field value (default: `false`)
    * `:indexed` - Whether to index the field (default: `true`)

  ## Examples

      iex> schema = Muninn.Schema.new()
      iex> schema = Muninn.Schema.add_f64_field(schema, "price", stored: true)
      iex> hd(schema.fields).type
      :f64

  """
  @spec add_f64_field(t(), String.t(), keyword()) :: t()
  def add_f64_field(%__MODULE__{fields: fields} = schema, name, opts \\ []) do
    field = Field.new(:f64, name, opts)
    %{schema | fields: fields ++ [field]}
  end

  @doc """
  Adds a boolean field to the schema.

  ## Options

    * `:stored` - Whether to store the field value (default: `false`)
    * `:indexed` - Whether to index the field (default: `true`)

  ## Examples

      iex> schema = Muninn.Schema.new()
      iex> schema = Muninn.Schema.add_bool_field(schema, "published", stored: true)
      iex> hd(schema.fields).type
      :bool

  """
  @spec add_bool_field(t(), String.t(), keyword()) :: t()
  def add_bool_field(%__MODULE__{fields: fields} = schema, name, opts \\ []) do
    field = Field.new(:bool, name, opts)
    %{schema | fields: fields ++ [field]}
  end

  @doc """
  Validates the schema.

  Returns `:ok` if valid, or `{:error, reason}` if invalid.

  ## Examples

      iex> schema = Muninn.Schema.new() |> Muninn.Schema.add_text_field("title")
      iex> Muninn.Schema.validate(schema)
      :ok

      iex> schema = Muninn.Schema.new()
      iex> Muninn.Schema.validate(schema)
      {:error, :no_fields}

  """
  @spec validate(t()) :: :ok | {:error, atom()}
  def validate(%__MODULE__{fields: []}) do
    {:error, :no_fields}
  end

  def validate(%__MODULE__{fields: fields}) do
    field_names = Enum.map(fields, & &1.name)
    unique_names = Enum.uniq(field_names)

    if length(field_names) == length(unique_names) do
      :ok
    else
      {:error, :duplicate_field_names}
    end
  end

  @doc """
  Converts the schema to a map representation for NIF consumption.

  ## Examples

      iex> schema = Muninn.Schema.new() |> Muninn.Schema.add_text_field("title", stored: true)
      iex> map = Muninn.Schema.to_map(schema)
      iex> is_map(map)
      true

  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{fields: fields}) do
    %{
      fields: Enum.map(fields, &Field.to_map/1)
    }
  end
end
