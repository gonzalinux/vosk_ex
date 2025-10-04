defmodule VoskNif do
  @moduledoc """
  Elixir NIF wrapper for Vosk speech recognition library.

  This module provides low-level bindings to the Vosk C API.
  For a more user-friendly interface, use VoskNif.Model and VoskNif.Recognizer.
  """

  @on_load :load_nifs

  def load_nifs do
    nif_file = :filename.join(:code.priv_dir(:vosk_nif), ~c"vosk_nif")

    case :erlang.load_nif(nif_file, 0) do
      :ok -> :ok
      {:error, {:load_failed, reason}} ->
        IO.warn("Failed to load NIF: #{inspect(reason)}")
        :ok
    end
  end

  # NIF stub functions (replaced at runtime)

  @doc """
  Set the log level for Vosk/Kaldi messages.

  - 0: default (info and errors)
  - < 0: silent
  - > 0: more verbose
  """
  def set_log_level(_level), do: :erlang.nif_error("NIF not loaded")

  @doc """
  Load a Vosk model from a directory path.

  Returns `{:ok, model_ref}` or `{:error, :model_load_failed}`.
  """
  def load_model(_path), do: :erlang.nif_error("NIF not loaded")

  @doc """
  Check if a word exists in the model vocabulary.

  Returns the word symbol (>= 0) if found, or -1 if not found.
  """
  def find_word(_model_ref, _word), do: :erlang.nif_error("NIF not loaded")

  @doc """
  Create a recognizer for the given model and sample rate.

  Returns `{:ok, recognizer_ref}` or `{:error, :recognizer_creation_failed}`.
  """
  def create_recognizer(_model_ref, _sample_rate), do: :erlang.nif_error("NIF not loaded")

  @doc """
  Set maximum number of alternatives to return in results.
  """
  def set_max_alternatives(_recognizer_ref, _max), do: :erlang.nif_error("NIF not loaded")

  @doc """
  Enable/disable word timing information in results.
  """
  def set_words(_recognizer_ref, _enabled), do: :erlang.nif_error("NIF not loaded")

  @doc """
  Enable/disable word timing information in partial results.
  """
  def set_partial_words(_recognizer_ref, _enabled), do: :erlang.nif_error("NIF not loaded")

  @doc """
  Process audio data (PCM 16-bit mono).

  Returns:
  - 1: utterance ended (silence detected)
  - 0: continue processing
  - -1: error occurred
  """
  def accept_waveform(_recognizer_ref, _audio_binary), do: :erlang.nif_error("NIF not loaded")

  @doc """
  Get recognition result as JSON string.

  Call this after accept_waveform returns 1.
  """
  def get_result(_recognizer_ref), do: :erlang.nif_error("NIF not loaded")

  @doc """
  Get partial recognition result as JSON string.

  This can be called while recognition is in progress.
  """
  def get_partial_result(_recognizer_ref), do: :erlang.nif_error("NIF not loaded")

  @doc """
  Get final recognition result as JSON string.

  Call this at the end of the stream to flush remaining audio.
  """
  def get_final_result(_recognizer_ref), do: :erlang.nif_error("NIF not loaded")

  @doc """
  Reset the recognizer to start fresh.
  """
  def reset_recognizer(_recognizer_ref), do: :erlang.nif_error("NIF not loaded")
end
