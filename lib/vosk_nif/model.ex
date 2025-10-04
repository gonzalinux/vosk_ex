defmodule VoskNif.Model do
  @moduledoc """
  High-level wrapper for Vosk speech recognition models.

  A model contains the acoustic and language data required for speech recognition.
  Models can be downloaded from https://alphacephei.com/vosk/models
  """

  @enforce_keys [:ref]
  defstruct [:ref]

  @type t :: %__MODULE__{ref: reference()}

  @doc """
  Load a model from a directory path.

  ## Examples

      iex> VoskNif.Model.load("path/to/vosk-model-small-en-us-0.15")
      {:ok, %VoskNif.Model{}}

      iex> VoskNif.Model.load("invalid/path")
      {:error, :model_load_failed}
  """
  @spec load(String.t()) :: {:ok, t()} | {:error, :model_load_failed}
  def load(path) when is_binary(path) do
    case VoskNif.load_model(path) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref}}
      error -> error
    end
  end

  @doc """
  Check if a word exists in the model's vocabulary.

  Returns the word symbol (>= 0) if found, or -1 if not found.

  ## Examples

      iex> model = VoskNif.Model.load!("path/to/model")
      iex> VoskNif.Model.find_word(model, "hello")
      42  # word symbol

      iex> VoskNif.Model.find_word(model, "xyzabc")
      -1  # not found
  """
  @spec find_word(t(), String.t()) :: integer()
  def find_word(%__MODULE__{ref: ref}, word) when is_binary(word) do
    VoskNif.find_word(ref, word)
  end

  @doc """
  Load a model from a directory path, raising on error.

  ## Examples

      iex> VoskNif.Model.load!("path/to/vosk-model")
      %VoskNif.Model{}
  """
  @spec load!(String.t()) :: t()
  def load!(path) do
    case load(path) do
      {:ok, model} -> model
      {:error, reason} -> raise "Failed to load model: #{reason}"
    end
  end

  defimpl Inspect do
    def inspect(%{ref: _}, _opts), do: "#VoskNif.Model<...>"
  end
end
