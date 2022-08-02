defmodule Clickhousex.Mixfile do
  use Mix.Project

  def project() do
    [
      app: :clickhousex,
      version: "0.5.0",
      elixir: "~> 1.5",
      deps: deps(),
      package: package(),
      source_url: "https://github.com/appodeal/clickhousex"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      applications: [:logger, :db_connection],
      # Should not be needed, but the warnings are everywhere
      extra_applications: [:jason, :tesla, :mint]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  def deps() do
    [
      {:db_connection, "~> 2.2"},
      {:mint, "~> 1.0"},
      {:tesla, "~> 1.4"},
      {:castore, "~> 0.1"},
      {:jason, "~> 1.2"},
      {:ex_doc, "~> 0.19", only: :dev},
      {:benchee, "~> 0.14.0", only: [:dev, :test]}
    ]
  end

  defp package() do
    [
      name: "clickhousex",
      description: description(),
      maintainers: maintainers(),
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/appodeal/clickhousex"}
    ]
  end

  defp description() do
    "ClickHouse driver for Elixir (uses HTTP)."
  end

  defp maintainers() do
    ["Roman Chudov", "Konstantin Grabar", "Ivan Zinoviev", "Evgeniy Shurmin", "Alexey Lukyanov"]
  end
end
