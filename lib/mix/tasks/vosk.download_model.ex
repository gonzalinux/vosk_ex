defmodule Mix.Tasks.Vosk.DownloadModel do
  @moduledoc """
  Downloads a Vosk speech recognition model for testing.

  ## Usage

      mix vosk.download_model [language|model_name]

  ## Predefined languages

  - en-us (default) - English US small model (~40MB)
  - en-us-large - English US large model (~1.8GB)
  - es - Spanish small model
  - fr - French small model
  - de - German small model
  - ru - Russian small model
  - cn - Chinese small model

  ## Custom models

  You can also specify a full model name from https://alphacephei.com/vosk/models:

      mix vosk.download_model vosk-model-ar-0.22-linto-1.1.0
      mix vosk.download_model vosk-model-small-ja-0.22

  ## Examples

      # Download default English model
      mix vosk.download_model

      # Download Spanish model
      mix vosk.download_model es

      # Download specific Arabic model
      mix vosk.download_model vosk-model-ar-0.22-linto-1.1.0

  Models are downloaded to: models/
  """

  use Mix.Task

  @shortdoc "Downloads a Vosk speech recognition model"

  @predefined_models %{
    "en-us" => "vosk-model-small-en-us-0.15",
    "en-us-large" => "vosk-model-en-us-0.22",
    "es" => "vosk-model-small-es-0.42",
    "fr" => "vosk-model-small-fr-0.22",
    "de" => "vosk-model-small-de-0.15",
    "ru" => "vosk-model-small-ru-0.22",
    "cn" => "vosk-model-small-cn-0.22",
    "ja" => "vosk-model-small-ja-0.22",
    "pt" => "vosk-model-small-pt-0.3",
    "it" => "vosk-model-small-it-0.22"
  }

  @base_url "https://alphacephei.com/vosk/models"
  @models_dir "models"

  @impl Mix.Task
  def run(args) do
    input = List.first(args) || "en-us"

    model_name = get_model_name(input)
    download_and_extract(model_name)
  end

  defp get_model_name(input) do
    cond do
      # Check if it's a predefined language code
      Map.has_key?(@predefined_models, input) ->
        @predefined_models[input]

      # Check if it looks like a model name (starts with vosk-model)
      String.starts_with?(input, "vosk-model") ->
        input

      # Unknown input
      true ->
        Mix.shell().error("Unknown language or invalid model name: #{input}")
        Mix.shell().info("")
        Mix.shell().info("Available predefined languages:")
        Enum.each(@predefined_models, fn {code, name} ->
          Mix.shell().info("  #{code} -> #{name}")
        end)
        Mix.shell().info("")
        Mix.shell().info("Or provide a full model name from https://alphacephei.com/vosk/models")
        Mix.shell().info("Example: vosk-model-ar-0.22-linto-1.1.0")
        System.halt(1)
    end
  end

  defp download_and_extract(model_name) do
    # Create models directory
    File.mkdir_p!(@models_dir)

    url = "#{@base_url}/#{model_name}.zip"
    zip_path = Path.join(@models_dir, "#{model_name}.zip")
    model_path = Path.join(@models_dir, model_name)

    # Check if model already exists
    if File.dir?(model_path) do
      Mix.shell().info("✓ Model already exists at: #{model_path}")
      Mix.shell().info("  Delete it to re-download.")
      show_usage_info(model_path)
    else
      download_model(url, zip_path, model_name)
      extract_model(zip_path, @models_dir)
      cleanup_zip(zip_path)
      show_usage_info(model_path)
    end
  end

  defp download_model(url, dest_path, model_name) do
    Mix.shell().info("Downloading #{model_name}...")
    Mix.shell().info("URL: #{url}")
    Mix.shell().info("This may take a few minutes...")
    Mix.shell().info("")

    # Use curl for download with progress
    case System.cmd("curl", [
      "-L",  # Follow redirects
      "--progress-bar",  # Show progress
      "-o", dest_path,
      url
    ], stderr_to_stdout: true) do
      {_output, 0} ->
        Mix.shell().info("")
        Mix.shell().info("✓ Download complete!")

      {output, _} ->
        Mix.shell().error("Download failed!")
        Mix.shell().error(output)
        Mix.shell().info("")
        Mix.shell().info("Please verify the model name exists at:")
        Mix.shell().info("https://alphacephei.com/vosk/models")
        File.rm(dest_path)
        System.halt(1)
    end
  end

  defp extract_model(zip_path, dest_dir) do
    Mix.shell().info("Extracting model...")

    case System.cmd("unzip", ["-q", "-o", zip_path, "-d", dest_dir]) do
      {_output, 0} ->
        Mix.shell().info("✓ Extraction complete!")

      {output, _} ->
        Mix.shell().error("Extraction failed: #{output}")
        Mix.shell().info("Make sure 'unzip' is installed on your system.")
        System.halt(1)
    end
  end

  defp cleanup_zip(zip_path) do
    File.rm(zip_path)
    Mix.shell().info("✓ Cleaned up temporary files")
  end

  defp show_usage_info(model_path) do
    Mix.shell().info("")
    Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    Mix.shell().info("Model ready at: #{model_path}")
    Mix.shell().info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    Mix.shell().info("")
    Mix.shell().info("Usage in code:")
    Mix.shell().info(~s|  {:ok, model} = VoskEx.Model.load("#{model_path}")|)
    Mix.shell().info("")
    Mix.shell().info("Run example:")
    Mix.shell().info(~s|  elixir examples/basic_recognition.exs #{model_path} audio.wav|)
    Mix.shell().info("")
    Mix.shell().info("Run tests with model:")
    Mix.shell().info(~s|  MODEL_PATH=#{model_path} mix test|)
    Mix.shell().info("")
  end
end
