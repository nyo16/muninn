defmodule Muninn.Native do
  @moduledoc """
  Native Implemented Functions (NIFs) for Muninn search engine.

  This module provides the low-level Rust bindings to the Tantivy search engine.
  All functions in this module are implemented in Rust using Rustler.
  """

  version = Mix.Project.config()[:version]
  github_url = "https://github.com/nyo16/muninn"

  # Determine build mode based on environment
  mode = if Mix.env() in [:dev, :test], do: :debug, else: :release

  # Legacy CPU detection function (defined at compile time)
  legacy_cpu_check = fn ->
    case :os.type() do
      {:unix, _} ->
        case System.cmd("grep", ["-q", "avx", "/proc/cpuinfo"], stderr_to_stdout: true) do
          {_, 0} -> false
          _ -> true
        end

      {:win32, _} ->
        System.get_env("MUNINN_LEGACY_CPU") in ["1", "true"]

      _ ->
        false
    end
  end

  use RustlerPrecompiled,
    otp_app: :muninn,
    crate: "muninn",
    version: version,
    base_url: "#{github_url}/releases/download/v#{version}",
    targets: ~w(
      aarch64-apple-darwin
      aarch64-unknown-linux-gnu
      x86_64-apple-darwin
      x86_64-unknown-linux-gnu
      x86_64-pc-windows-gnu
    ),
    variants: %{
      "x86_64-unknown-linux-gnu" => [legacy_cpu: legacy_cpu_check],
      "x86_64-pc-windows-gnu" => [legacy_cpu: legacy_cpu_check]
    },
    nif_versions: ["2.15", "2.16"],
    mode: mode,
    force_build: System.get_env("MUNINN_BUILD") in ["1", "true"]

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

  ## Reader functions

  @doc false
  def reader_new(_index), do: :erlang.nif_error(:nif_not_loaded)

  ## Searcher functions

  @doc false
  def searcher_new(_reader), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def searcher_search_term(_searcher, _query, _limit), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def searcher_search_query(_searcher, _query_string, _default_fields, _limit),
    do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def searcher_search_with_snippets(
        _searcher,
        _query_string,
        _default_fields,
        _snippet_fields,
        _max_snippet_chars,
        _limit
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def searcher_search_prefix(_searcher, _field_name, _prefix, _limit),
    do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def searcher_search_range_u64(
        _searcher,
        _field_name,
        _lower,
        _upper,
        _lower_inclusive,
        _upper_inclusive,
        _limit
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def searcher_search_range_i64(
        _searcher,
        _field_name,
        _lower,
        _upper,
        _lower_inclusive,
        _upper_inclusive,
        _limit
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def searcher_search_range_f64(
        _searcher,
        _field_name,
        _lower,
        _upper,
        _lower_inclusive,
        _upper_inclusive,
        _limit
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def searcher_search_fuzzy(
        _searcher,
        _field_name,
        _term,
        _distance,
        _transposition_cost_one,
        _limit
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def searcher_search_fuzzy_prefix(
        _searcher,
        _field_name,
        _prefix,
        _distance,
        _transposition_cost_one,
        _limit
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def searcher_search_fuzzy_with_snippets(
        _searcher,
        _field_name,
        _term,
        _snippet_fields,
        _distance,
        _transposition_cost_one,
        _max_snippet_chars,
        _limit
      ),
      do: :erlang.nif_error(:nif_not_loaded)
end
