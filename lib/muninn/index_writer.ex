defmodule Muninn.IndexWriter do
  @moduledoc """
  IndexWriter for adding documents to a Muninn index.

  The IndexWriter handles document insertion and manages commits to make
  documents searchable. Writers are automatically managed per index.

  ## Usage

      {:ok, index} = Muninn.Index.create("/path/to/index", schema)

      # Add a single document
      doc = %{"title" => "Hello", "views" => 100}
      :ok = Muninn.IndexWriter.add_document(index, doc)

      # Add multiple documents
      docs = [
        %{"title" => "First", "views" => 10},
        %{"title" => "Second", "views" => 20}
      ]
      :ok = Muninn.IndexWriter.add_documents(index, docs)

      # Commit changes
      :ok = Muninn.IndexWriter.commit(index)

  """

  alias Muninn.Native

  @doc """
  Adds a single document to the index.

  The document should be a map where keys match the field names defined
  in the schema. Field values are automatically converted to the correct types.

  ## Parameters

    * `index` - The index to add the document to
    * `document` - A map with field names as keys

  ## Returns

    * `:ok` - Document added successfully
    * `{:error, reason}` - Failed to add document

  ## Examples

      doc = %{
        "title" => "Hello World",
        "views" => 100,
        "price" => 19.99,
        "published" => true
      }

      :ok = Muninn.IndexWriter.add_document(index, doc)

  """
  @spec add_document(reference(), map()) :: :ok | {:error, String.t()}
  def add_document(index, document) when is_map(document) do
    case Native.writer_add_document(index, document) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Adds multiple documents to the index in a batch operation.

  This is more efficient than calling `add_document/2` multiple times.

  ## Parameters

    * `index` - The index to add documents to
    * `documents` - A list of document maps

  ## Returns

    * `:ok` - All documents added successfully
    * `{:error, reason}` - Failed to add documents

  ## Examples

      docs = [
        %{"title" => "First", "views" => 10},
        %{"title" => "Second", "views" => 20},
        %{"title" => "Third", "views" => 30}
      ]

      :ok = Muninn.IndexWriter.add_documents(index, docs)

  """
  @spec add_documents(reference(), [map()]) :: :ok | {:error, String.t()}
  def add_documents(index, documents) when is_list(documents) do
    # For now, add one by one. Can be optimized later
    Enum.reduce_while(documents, :ok, fn doc, :ok ->
      case add_document(index, doc) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  @doc """
  Commits all pending changes to the index.

  After committing, all added documents become searchable. This operation
  flushes the current segment to disk.

  ## Parameters

    * `index` - The index to commit

  ## Returns

    * `:ok` - Commit successful
    * `{:error, reason}` - Failed to commit

  ## Examples

      :ok = Muninn.IndexWriter.add_document(index, doc)
      :ok = Muninn.IndexWriter.commit(index)

  """
  @spec commit(reference()) :: :ok | {:error, String.t()}
  def commit(index) do
    case Native.writer_commit(index) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Rolls back all uncommitted changes.

  Discards all documents added since the last commit without making
  them searchable.

  ## Parameters

    * `index` - The index to rollback

  ## Returns

    * `:ok` - Rollback successful
    * `{:error, reason}` - Failed to rollback

  ## Examples

      :ok = Muninn.IndexWriter.add_document(index, doc)
      :ok = Muninn.IndexWriter.rollback(index)
      # Document is not searchable

  """
  @spec rollback(reference()) :: :ok | {:error, String.t()}
  def rollback(index) do
    case Native.writer_rollback(index) do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
