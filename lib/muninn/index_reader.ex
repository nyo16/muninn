defmodule Muninn.IndexReader do
  @moduledoc """
  IndexReader provides access to search an index.

  The IndexReader is the entry point for searching. It manages the underlying
  index segments and provides searchers for executing queries.

  ## Usage

      {:ok, index} = Muninn.Index.open("/path/to/index")
      {:ok, reader} = Muninn.IndexReader.new(index)
      {:ok, searcher} = Muninn.Searcher.new(reader)

  ## Lifecycle

  Readers are automatically managed and cleaned up by the BEAM garbage collector.
  No explicit close is required.

  """

  alias Muninn.Native

  @type t :: reference()

  @doc """
  Creates a new IndexReader for the given index.

  The reader provides access to search the index and retrieve documents.

  ## Parameters

    * `index` - The index to create a reader for

  ## Returns

    * `{:ok, reader}` - Successfully created reader
    * `{:error, reason}` - Failed to create reader

  ## Examples

      {:ok, index} = Muninn.Index.open("/tmp/my_index")
      {:ok, reader} = Muninn.IndexReader.new(index)

  """
  @spec new(reference()) :: {:ok, t()} | {:error, String.t()}
  def new(index) do
    Native.reader_new(index)
  end
end
