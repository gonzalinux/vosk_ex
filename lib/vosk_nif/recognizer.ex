defmodule VoskNif.Recognizer do
  @moduledoc """
  High-level wrapper for Vosk speech recognizer.

  A recognizer processes audio data and returns speech recognition results.
  """

  @enforce_keys [:ref]
  defstruct [:ref]

  @type t :: %__MODULE__{ref: reference()}
  @type waveform_result :: :utterance_ended | :continue | :error
  @type recognition_result :: %{optional(String.t()) => any()}

  @doc """
  Create a new recognizer for the given model and sample rate.

  ## Parameters

  - `model`: A VoskNif.Model struct
  - `sample_rate`: Audio sample rate in Hz (typically 8000, 16000, or 44100)

  ## Examples

      iex> model = VoskNif.Model.load!("path/to/model")
      iex> VoskNif.Recognizer.new(model, 16000.0)
      {:ok, %VoskNif.Recognizer{}}
  """
  @spec new(VoskNif.Model.t(), float()) :: {:ok, t()} | {:error, :recognizer_creation_failed}
  def new(%VoskNif.Model{ref: model_ref}, sample_rate) when is_number(sample_rate) do
    case VoskNif.create_recognizer(model_ref, sample_rate / 1.0) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref}}
      error -> error
    end
  end

  @doc """
  Create a new recognizer, raising on error.
  """
  @spec new!(VoskNif.Model.t(), float()) :: t()
  def new!(model, sample_rate) do
    case new(model, sample_rate) do
      {:ok, recognizer} -> recognizer
      {:error, reason} -> raise "Failed to create recognizer: #{reason}"
    end
  end

  @doc """
  Set maximum number of recognition alternatives to return.

  ## Examples

      iex> VoskNif.Recognizer.set_max_alternatives(recognizer, 3)
      :ok
  """
  @spec set_max_alternatives(t(), integer()) :: :ok
  def set_max_alternatives(%__MODULE__{ref: ref}, max) when is_integer(max) do
    VoskNif.set_max_alternatives(ref, max)
  end

  @doc """
  Enable or disable word timing information in results.

  When enabled, results include start/end times and confidence for each word.

  ## Examples

      iex> VoskNif.Recognizer.set_words(recognizer, true)
      :ok
  """
  @spec set_words(t(), boolean()) :: :ok
  def set_words(%__MODULE__{ref: ref}, enabled) when is_boolean(enabled) do
    VoskNif.set_words(ref, if(enabled, do: 1, else: 0))
  end

  @doc """
  Enable or disable word timing information in partial results.

  ## Examples

      iex> VoskNif.Recognizer.set_partial_words(recognizer, true)
      :ok
  """
  @spec set_partial_words(t(), boolean()) :: :ok
  def set_partial_words(%__MODULE__{ref: ref}, enabled) when is_boolean(enabled) do
    VoskNif.set_partial_words(ref, if(enabled, do: 1, else: 0))
  end

  @doc """
  Process audio data.

  ## Parameters

  - `audio_data`: Binary containing PCM 16-bit mono audio data

  ## Returns

  - `:utterance_ended` - Silence detected, call `result/1` to get recognition
  - `:continue` - Keep feeding audio, can call `partial_result/1` for progress
  - `:error` - An error occurred

  ## Examples

      iex> audio = File.read!("audio.raw")
      iex> VoskNif.Recognizer.accept_waveform(recognizer, audio)
      :utterance_ended
  """
  @spec accept_waveform(t(), binary()) :: waveform_result()
  def accept_waveform(%__MODULE__{ref: ref}, audio_data) when is_binary(audio_data) do
    case VoskNif.accept_waveform(ref, audio_data) do
      1 -> :utterance_ended
      0 -> :continue
      -1 -> :error
    end
  end

  @doc """
  Get the final recognition result as a parsed map.

  Call this after `accept_waveform/2` returns `:utterance_ended`.

  ## Examples

      iex> VoskNif.Recognizer.result(recognizer)
      {:ok, %{"text" => "hello world"}}
  """
  @spec result(t()) :: {:ok, recognition_result()} | {:error, Jason.DecodeError.t()}
  def result(%__MODULE__{ref: ref}) do
    ref
    |> VoskNif.get_result()
    |> Jason.decode()
  end

  @doc """
  Get the current partial recognition result as a parsed map.

  Can be called while recognition is in progress.

  ## Examples

      iex> VoskNif.Recognizer.partial_result(recognizer)
      {:ok, %{"partial" => "hello wor"}}
  """
  @spec partial_result(t()) :: {:ok, recognition_result()} | {:error, Jason.DecodeError.t()}
  def partial_result(%__MODULE__{ref: ref}) do
    ref
    |> VoskNif.get_partial_result()
    |> Jason.decode()
  end

  @doc """
  Get the final result at the end of the audio stream.

  This flushes the feature pipeline to process any remaining audio.

  ## Examples

      iex> VoskNif.Recognizer.final_result(recognizer)
      {:ok, %{"text" => "hello world"}}
  """
  @spec final_result(t()) :: {:ok, recognition_result()} | {:error, Jason.DecodeError.t()}
  def final_result(%__MODULE__{ref: ref}) do
    ref
    |> VoskNif.get_final_result()
    |> Jason.decode()
  end

  @doc """
  Reset the recognizer to start fresh.

  Clears all current recognition state.

  ## Examples

      iex> VoskNif.Recognizer.reset(recognizer)
      :ok
  """
  @spec reset(t()) :: :ok
  def reset(%__MODULE__{ref: ref}) do
    VoskNif.reset_recognizer(ref)
  end

  defimpl Inspect do
    def inspect(%{ref: _}, _opts), do: "#VoskNif.Recognizer<...>"
  end
end
