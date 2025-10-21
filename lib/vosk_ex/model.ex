defmodule VoskEx.Model do
  @moduledoc """
  High-level wrapper for Vosk speech recognition model.

  A model represents a trained language model that can be used to create recognizers.
  Models are loaded once and can be shared across multiple recognizers and processes.

  ## Model Sources

  Models can be downloaded from [Vosk Models](https://alphacephei.com/vosk/models).
  Available languages include: English, Spanish, German, French, Russian, Chinese, and many more.

  Use the Mix task to download models easily:

  ```bash
  mix vosk.download_model en          # Download small English model
  mix vosk.download_model es          # Download Spanish model
  mix vosk.download_model vosk-model-small-en-us-0.15  # Download specific model
  ```

  ## Thread Safety

  Models are thread-safe and reference-counted by Vosk. You can safely share a model
  across multiple processes and recognizers. Resources are automatically cleaned up
  when no longer referenced.
  """

  @enforce_keys [:ref]
  defstruct [:ref]

  @type t :: %__MODULE__{ref: reference()}

  @doc """
  Load a model from a directory path.

  ## Examples

      iex> VoskEx.Model.load("path/to/vosk-model-small-en-us-0.15")
      {:ok, %VoskEx.Model{}}

      iex> VoskEx.Model.load("invalid/path")
      {:error, :model_load_failed}
  """
  @spec load(String.t()) :: {:ok, t()} | {:error, :model_load_failed}
  def load(path) when is_binary(path) do
    case VoskEx.load_model(path) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref}}
      error -> error
    end
  end

  @doc """
  Load a model from a directory path, raising on error.

  ## Examples

      iex> VoskEx.Model.load!("path/to/vosk-model")
      %VoskEx.Model{}
  """
  @spec load!(String.t()) :: t()
  def load!(path) do
    case load(path) do
      {:ok, model} -> model
      {:error, reason} -> raise "Failed to load model: #{reason}"
    end
  end

  defimpl Inspect do
    def inspect(%{ref: _}, _opts), do: "#VoskEx.Model<...>"
  end
end
