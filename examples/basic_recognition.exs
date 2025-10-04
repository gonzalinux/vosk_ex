#!/usr/bin/env elixir

# Example: Basic speech recognition with VoskEx
#
# Usage:
#   1. Download a model from https://alphacephei.com/vosk/models
#   2. Prepare a 16kHz mono WAV file
#   3. Run: elixir examples/basic_recognition.exs <model_path> <audio_file>

defmodule BasicRecognition do
  def run([model_path, audio_file]) do
    IO.puts("Loading model from #{model_path}...")
    {:ok, model} = VoskEx.Model.load(model_path)
    IO.puts("Model loaded successfully!")

    IO.puts("Creating recognizer...")
    {:ok, recognizer} = VoskEx.Recognizer.new(model, 16000.0)

    # Enable word timing
    VoskEx.Recognizer.set_words(recognizer, true)

    IO.puts("Reading audio file: #{audio_file}...")
    # Read audio and skip WAV header (44 bytes)
    audio = File.read!(audio_file)
    audio = if String.ends_with?(audio_file, ".wav") do
      binary_part(audio, 44, byte_size(audio) - 44)
    else
      audio
    end

    IO.puts("Processing audio (#{byte_size(audio)} bytes)...")

    # Process in 8KB chunks
    chunk_size = 8000
    chunks = for <<chunk::binary-size(chunk_size) <- audio>>, do: chunk

    Enum.each(chunks, fn chunk ->
      case VoskEx.Recognizer.accept_waveform(recognizer, chunk) do
        :utterance_ended ->
          {:ok, result} = VoskEx.Recognizer.result(recognizer)
          IO.puts("\n[UTTERANCE] #{inspect(result)}")

        :continue ->
          {:ok, partial} = VoskEx.Recognizer.partial_result(recognizer)
          IO.write("\r[PARTIAL] #{partial["partial"] || ""}")

        :error ->
          IO.puts("\nError processing audio!")
      end
    end)

    IO.puts("\n\nGetting final result...")
    {:ok, final} = VoskEx.Recognizer.final_result(recognizer)
    IO.puts("[FINAL] #{inspect(final)}")

    if text = final["text"] do
      IO.puts("\n✓ Recognized text: \"#{text}\"")
    end
  end

  def run(_) do
    IO.puts("""
    Usage: elixir basic_recognition.exs <model_path> <audio_file>

    Example:
      elixir basic_recognition.exs vosk-model-small-en-us-0.15 audio.wav

    Download models from: https://alphacephei.com/vosk/models
    """)
    System.halt(1)
  end
end

BasicRecognition.run(System.argv())
