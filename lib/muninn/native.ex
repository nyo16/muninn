defmodule Muninn.Native do
  @moduledoc """
  Native Implemented Functions (NIFs) for Muninn search engine.

  This module provides the low-level Rust bindings to the Tantivy search engine.
  All functions in this module are implemented in Rust using Rustler.
  """

  use Rustler, otp_app: :muninn, crate: "muninn"

  # When the NIF is loaded, it will replace these function implementations.
  # These are just stubs that will raise an error if the NIF fails to load.

  ## Schema functions

  @doc false
  def schema_build(_fields_list), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def schema_num_fields(_schema), do: :erlang.nif_error(:nif_not_loaded)

  ## Index functions

  @doc false
  def index_create(_path, _fields_list), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def index_open(_path), do: :erlang.nif_error(:nif_not_loaded)

  ## Writer functions

  @doc false
  def writer_add_document(_index, _document), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def writer_commit(_index), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def writer_rollback(_index), do: :erlang.nif_error(:nif_not_loaded)
end
