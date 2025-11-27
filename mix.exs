defmodule Muninn.MixProject do
  use Mix.Project

  @version "0.4.0"
  @source_url "https://github.com/nyo16/muninn"

  def project do
    [
      app: :muninn,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Muninn",
      source_url: @source_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Muninn.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Production dependencies
      {:rustler, ">= 0.0.0", optional: true},
      {:rustler_precompiled, "~> 0.8.0"},
      {:jason, "~> 1.4"},

      # Development dependencies
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    A fast, full-text search engine for Elixir, powered by Tantivy (Rust).
    Features include fuzzy matching, range queries, highlighting, and autocomplete.
    """
  end

  defp package do
    [
      name: "muninn",
      files: ~w(lib native .formatter.exs mix.exs README.md LICENSE checksum-*.exs),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/master/CHANGELOG.md"
      },
      maintainers: ["Niko"]
    ]
  end

  defp docs do
    [
      main: "Muninn",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "LICENSE", "CHANGELOG.md"]
    ]
  end
end
