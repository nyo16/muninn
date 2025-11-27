ExUnit.start()

defmodule Muninn.TestHelpers do
  @moduledoc """
  Helper functions for tests.
  """

  @doc """
  Safely removes a directory with retries.
  On Linux CI, file locks from NIFs can cause rm_rf to fail if called too quickly.
  """
  def safe_rm_rf(path, retries \\ 3) do
    case File.rm_rf(path) do
      {:ok, _} ->
        :ok

      {:error, _reason, _file} when retries > 0 ->
        # Give the NIF resources time to be garbage collected
        :timer.sleep(100)
        safe_rm_rf(path, retries - 1)

      {:error, _reason, _file} ->
        # Final attempt failed, but don't crash the test
        :ok
    end
  end
end
