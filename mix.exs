defmodule MobMarkdown.MixProject do
  use Mix.Project

  @source_url "https://github.com/GenericJam/mob_markdown"
  @version "0.1.0"

  def project do
    [
      app: :mob_markdown,
      version: @version,
      elixir: "~> 1.17",
      deps: deps(),
      aliases: aliases(),
      description:
        "Native Markdown views for Mob apps: Markwon in a selectable TextView on Android, " <>
          "Foundation's Markdown parser in a selectable UITextView on iOS.",
      package: package(),
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"]
      ],
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp aliases do
    # `mix setup` after cloning: fetches deps and activates the shared git
    # hooks (.githooks): format / Credo --strict / compile on every push and
    # the full suite when mix.exs changes, the same gate CI enforces.
    [setup: ["deps.get", "cmd git config core.hooksPath .githooks"]]
  end

  defp deps do
    [
      {:mob, "~> 0.9"},
      # Test-only: the manifest tests run mob_dev's real pre-publish validator.
      {:mob_dev, "~> 0.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4.2", only: [:dev, :test], runtime: false},
      {:jump_credo_checks, "~> 0.1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      # The native sources and the manifest ship in the package: the host's
      # native build compiles them from deps/mob_markdown/priv.
      files: ~w(lib priv mix.exs README* CHANGELOG* LICENSE* NOTICE*)
    ]
  end
end
