defmodule VoskExApiTest do
  use ExUnit.Case
  doctest VoskEx

  @model_path System.get_env("MODEL_PATH") || "models/vosk-model-small-en-us-0.15"

  test "NIF module loads successfully" do
    # This test verifies the NIF loads without errors
    assert function_exported?(VoskEx, :set_log_level, 1)
    assert function_exported?(VoskEx, :load_model, 1)
    assert function_exported?(VoskEx, :create_recognizer, 2)
    assert function_exported?(VoskEx, :accept_waveform, 2)
    assert function_exported?(VoskEx, :get_result, 1)
    assert function_exported?(VoskEx, :get_partial_result, 1)
    assert function_exported?(VoskEx, :get_final_result, 1)
  end

  test "set_log_level works" do
    # Set log level to silent
    assert VoskEx.set_log_level(-1) == :ok
    # Set log level to verbose
    assert VoskEx.set_log_level(1) == :ok
    # Set log level to default
    assert VoskEx.set_log_level(0) == :ok
    # Reset back to silent for other tests
    assert VoskEx.set_log_level(-1) == :ok
  end

  test "Model and Recognizer modules are loaded" do
    assert Code.ensure_loaded?(VoskEx.Model)
    assert Code.ensure_loaded?(VoskEx.Recognizer)
  end

  @tag :integration
  test "can load a valid model" do
    if File.dir?(@model_path) do
      {:ok, model} = VoskEx.Model.load(@model_path)
      assert %VoskEx.Model{ref: ref} = model
      assert is_reference(ref)
    else
      IO.puts("\nSkipping model test - model not found at #{@model_path}")
      IO.puts("Run: mix vosk.download_model")
    end
  end

  @tag :integration
  test "can create a recognizer" do
    if File.dir?(@model_path) do
      {:ok, model} = VoskEx.Model.load(@model_path)
      {:ok, recognizer} = VoskEx.Recognizer.new(model, 16000.0)
      assert %VoskEx.Recognizer{ref: ref} = recognizer
      assert is_reference(ref)
    else
      IO.puts("\nSkipping recognizer test - model not found")
    end
  end

  @tag :integration
  test "can process audio data" do
    if File.dir?(@model_path) do
      {:ok, model} = VoskEx.Model.load(@model_path)
      {:ok, recognizer} = VoskEx.Recognizer.new(model, 16000.0)

      # Create some dummy PCM audio data (silence)
      dummy_audio = <<0::16-signed-little, 0::16-signed-little>> |> String.duplicate(4000)

      # Should return :continue for silence
      result = VoskEx.Recognizer.accept_waveform(recognizer, dummy_audio)
      assert result in [:continue, :utterance_ended]

      # Should be able to get partial result
      {:ok, partial} = VoskEx.Recognizer.partial_result(recognizer)
      assert is_map(partial)
      assert Map.has_key?(partial, "partial")

      # Should be able to get final result
      {:ok, final} = VoskEx.Recognizer.final_result(recognizer)
      assert is_map(final)
      assert Map.has_key?(final, "text")
    else
      IO.puts("\nSkipping audio processing test - model not found")
    end
  end

  @tag :integration
  test "transcribes test_audio.raw file" do
    audio_path = "test/test_audio.raw"

    if File.dir?(@model_path) and File.exists?(audio_path) do
      {:ok, model} = VoskEx.Model.load(@model_path)
      {:ok, recognizer} = VoskEx.Recognizer.new(model, 16000.0)

      # Read raw PCM data directly
      pcm_data = File.read!(audio_path)

      # Process the audio
      VoskEx.Recognizer.accept_waveform(recognizer, pcm_data)

      # Get final result
      {:ok, result} = VoskEx.Recognizer.final_result(recognizer)

      # Assert the transcription matches expected text
      assert result["text"] ==
               "hello one two three welcome to this demonstration thank you for listening"
    else
      if not File.dir?(@model_path) do
        IO.puts("\nSkipping transcription test - model not found at #{@model_path}")
        IO.puts("Run: mix vosk.download_model")
      end

      if not File.exists?(audio_path) do
        IO.puts("\nSkipping transcription test - audio file not found at #{audio_path}")
      end
    end
  end
end
