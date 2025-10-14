defmodule TamaEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :tama_ex,
      version: "0.1.10",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "TamaEx",
      source_url: "https://github.com/upmaru/tama-ex",
      docs: [
        main: "TamaEx",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "An Elixir HTTP client wrapper with structured response handling and schema parsing support."
  end

  defp package do
    [
      name: "tama_ex",
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/upmaru/tama-ex",
        "Changelog" => "https://github.com/upmaru/tama-ex/blob/main/CHANGELOG.md"
      },
      maintainers: ["Zack Siri"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.13"},
      {:req, "~> 0.5"},
      {:bypass, "~> 2.1", only: :test},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end
end
