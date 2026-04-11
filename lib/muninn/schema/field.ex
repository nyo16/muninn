defmodule Muninn.Schema.Field do
  @moduledoc """
  Represents a field in a Muninn schema.
  """

  @type field_type :: :text | :u64 | :i64 | :f64 | :bool | :date | :facet | :bytes | :json

  @type t :: %__MODULE__{
          type: field_type(),
          name: String.t(),
          stored: boolean(),
          indexed: boolean(),
          fast: boolean(),
          tokenizer: String.t() | nil
        }

  defstruct [:type, :name, stored: false, indexed: true, fast: false, tokenizer: nil]

  @doc """
  Creates a new field.

  ## Options

    * `:stored` - Whether to store the field value (default: `false`)
    * `:indexed` - Whether to index the field (default: `true`)
    * `:fast` - Whether to enable fast field (columnar) storage (default: `false`).
      Required for sorting and aggregations on numeric fields.
    * `:tokenizer` - Tokenizer to use for text fields (default: `nil`, uses `"default"`).
      Built-in options: `"default"`, `"raw"`, `"en_stem"`, `"whitespace"`.

  """
  @spec new(field_type(), String.t(), keyword()) :: t()
  def new(type, name, opts \\ []) do
    %__MODULE__{
      type: type,
      name: name,
      stored: Keyword.get(opts, :stored, false),
      indexed: Keyword.get(opts, :indexed, true),
      fast: Keyword.get(opts, :fast, false),
      tokenizer: Keyword.get(opts, :tokenizer, nil)
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
      indexed: field.indexed,
      fast: field.fast,
      tokenizer: field.tokenizer || "default"
    }
  end
end
