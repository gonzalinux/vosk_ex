defmodule VoskEx.Recognizer do
  @moduledoc """
  High-level wrapper for Vosk speech recognizer.

  A recognizer processes audio data and returns speech recognition results.
  Each recognizer is bound to a specific model and sample rate.

  ## Audio Requirements

  The recognizer expects PCM 16-bit mono audio at the specified sample rate:
  - **Format**: PCM (uncompressed)
  - **Bit depth**: 16-bit signed integers
  - **Channels**: Mono (single channel)
  - **Sample rate**: Must match the rate specified at creation (typically 8000, 16000, or 44100 Hz)
  - **Byte order**: Little-endian

  For WAV files, skip the 44-byte header before passing audio to the recognizer.

  ## Recognition Flow

  1. Create a recognizer with a model and sample rate
  2. Feed audio data using `accept_waveform/2`
  3. Check for results:
     - `:utterance_ended` → call `result/1` for final text
     - `:continue` → call `partial_result/1` for interim text
  4. At end of audio, call `final_result/1` to flush remaining data

  ## Thread Safety

  Recognizers are **NOT thread-safe**. Each process should create its own recognizer instance.
  However, multiple recognizers can safely share the same model.

  ## Example

  ```elixir
  # Load model once
  {:ok, model} = VoskEx.Model.load("models/vosk-model-small-en-us-0.15")

  # Create recognizer
  {:ok, rec} = VoskEx.Recognizer.new(model, 16000.0)
  VoskEx.Recognizer.set_words(rec, true)  # Enable word timings

  # Process audio in chunks
  audio_chunks = read_audio_in_chunks("audio.wav")
  for chunk <- audio_chunks do
    case VoskEx.Recognizer.accept_waveform(rec, chunk) do
      :utterance_ended ->
        {:ok, result} = VoskEx.Recognizer.result(rec)
        IO.puts("Final: \#{result["text"]}")

      :continue ->
        {:ok, partial} = VoskEx.Recognizer.partial_result(rec)
        IO.puts("Partial: \#{partial["partial"]}")
    end
  end

  # Get any remaining text
  {:ok, final} = VoskEx.Recognizer.final_result(rec)
  IO.puts("Final: \#{final["text"]}")
  ```
  """

  @enforce_keys [:ref]
  defstruct [:ref]

  @type t :: %__MODULE__{ref: reference()}
  @type waveform_result :: :utterance_ended | :continue | :error
  @type recognition_result :: %{optional(String.t()) => any()}

  @doc """
  Create a new recognizer for the given model and sample rate.

  ## Parameters

  - `model`: A VoskEx.Model struct
  - `sample_rate`: Audio sample rate in Hz (typically 8000, 16000, or 44100)

  ## Examples

      iex> model = VoskEx.Model.load!("path/to/model")
      iex> VoskEx.Recognizer.new(model, 16000.0)
      {:ok, %VoskEx.Recognizer{}}
  """
  @spec new(VoskEx.Model.t(), float()) :: {:ok, t()} | {:error, :recognizer_creation_failed}
  def new(%VoskEx.Model{ref: model_ref}, sample_rate) when is_number(sample_rate) do
    case VoskEx.create_recognizer(model_ref, sample_rate / 1.0) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref}}
      error -> error
    end
  end

  @doc """
  Create a new recognizer, raising on error.
  """
  @spec new!(VoskEx.Model.t(), float()) :: t()
  def new!(model, sample_rate) do
    case new(model, sample_rate) do
      {:ok, recognizer} -> recognizer
      {:error, reason} -> raise "Failed to create recognizer: #{reason}"
    end
  end

  @doc """
  Set maximum number of recognition alternatives to return.

  ## Examples

      iex> VoskEx.Recognizer.set_max_alternatives(recognizer, 3)
      :ok
  """
  @spec set_max_alternatives(t(), integer()) :: :ok
  def set_max_alternatives(%__MODULE__{ref: ref}, max) when is_integer(max) do
    VoskEx.set_max_alternatives(ref, max)
  end

  @doc """
  Enable or disable word timing information in results.

  When enabled, results include start/end times and confidence for each word.

  ## Examples

      iex> VoskEx.Recognizer.set_words(recognizer, true)
      :ok
  """
  @spec set_words(t(), boolean()) :: :ok
  def set_words(%__MODULE__{ref: ref}, enabled) when is_boolean(enabled) do
    VoskEx.set_words(ref, if(enabled, do: 1, else: 0))
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
      iex> VoskEx.Recognizer.accept_waveform(recognizer, audio)
      :utterance_ended
  """
  @spec accept_waveform(t(), binary()) :: waveform_result()
  def accept_waveform(%__MODULE__{ref: ref}, audio_data) when is_binary(audio_data) do
    case VoskEx.accept_waveform(ref, audio_data) do
      1 -> :utterance_ended
      0 -> :continue
      -1 -> :error
    end
  end

  @doc """
  Get the final recognition result as a parsed map.

  Call this after `accept_waveform/2` returns `:utterance_ended`.

  ## Examples

      iex> VoskEx.Recognizer.result(recognizer)
      {:ok, %{"text" => "hello world"}}
  """
  @spec result(t()) :: {:ok, recognition_result()} | {:error, Jason.DecodeError.t()}
  def result(%__MODULE__{ref: ref}) do
    ref
    |> VoskEx.get_result()
    |> Jason.decode()
  end

  @doc """
  Get the current partial recognition result as a parsed map.

  Can be called while recognition is in progress.

  ## Examples

      iex> VoskEx.Recognizer.partial_result(recognizer)
      {:ok, %{"partial" => "hello wor"}}
  """
  @spec partial_result(t()) :: {:ok, recognition_result()} | {:error, Jason.DecodeError.t()}
  def partial_result(%__MODULE__{ref: ref}) do
    ref
    |> VoskEx.get_partial_result()
    |> Jason.decode()
  end

  @doc """
  Get the final result at the end of the audio stream.

  This flushes the feature pipeline to process any remaining audio.

  ## Examples

      iex> VoskEx.Recognizer.final_result(recognizer)
      {:ok, %{"text" => "hello world"}}
  """
  @spec final_result(t()) :: {:ok, recognition_result()} | {:error, Jason.DecodeError.t()}
  def final_result(%__MODULE__{ref: ref}) do
    ref
    |> VoskEx.get_final_result()
    |> Jason.decode()
  end

  @doc """
  Reset the recognizer to start fresh.

  Clears all current recognition state.

  ## Examples

      iex> VoskEx.Recognizer.reset(recognizer)
      :ok
  """
  @spec reset(t()) :: :ok
  def reset(%__MODULE__{ref: ref}) do
    VoskEx.reset_recognizer(ref)
  end

  defimpl Inspect do
    def inspect(%{ref: _}, _opts), do: "#VoskEx.Recognizer<...>"
  end
end
