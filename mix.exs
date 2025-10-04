defmodule VoskEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :vosk_ex,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_targets: ["all"],
      make_clean: ["clean"],
      deps: deps(),

      # Documentation
      name: "VoskEx",
      source_url: "https://github.com/yourusername/vosk_ex",
      homepage_url: "https://github.com/yourusername/vosk_ex",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {VoskEx.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_make, "~> 0.8", runtime: false},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "VoskEx",
      extras: ["README.md"],
      groups_for_modules: [
        "Core API": [VoskEx, VoskEx.Model, VoskEx.Recognizer],
        "Mix Tasks": [Mix.Tasks.Vosk.DownloadModel]
      ],
      assets: %{"assets" => "assets"}
    ]
  end
end
