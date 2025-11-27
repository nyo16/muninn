defmodule Muninn.Schema.Field do
  @moduledoc """
  Represents a field in a Muninn schema.
  """

  @type field_type :: :text | :u64 | :i64 | :f64 | :bool | :date | :facet | :bytes | :json

  @type t :: %__MODULE__{
          type: field_type(),
          name: String.t(),
          stored: boolean(),
          indexed: boolean()
        }

  defstruct [:type, :name, stored: false, indexed: true]

  @doc """
  Creates a new field.

  ## Options

    * `:stored` - Whether to store the field value (default: `false`)
    * `:indexed` - Whether to index the field (default: `true`)

  """
  @spec new(field_type(), String.t(), keyword()) :: t()
  def new(type, name, opts \\ []) do
    %__MODULE__{
      type: type,
      name: name,
      stored: Keyword.get(opts, :stored, false),
      indexed: Keyword.get(opts, :indexed, true)
    }
  end

  @doc """
  Converts a field to a map representation.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = field) do
    %{
      type: Atom.to_string(field.type),
      name: field.name,
      stored: field.stored,
      indexed: field.indexed
    }
  end
end
