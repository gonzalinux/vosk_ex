defmodule VoskNifApiTest do
  use ExUnit.Case
  doctest VoskNif

  @model_path System.get_env("MODEL_PATH") || "models/vosk-model-small-en-us-0.15"

  test "NIF module loads successfully" do
    # This test verifies the NIF loads without errors
    assert function_exported?(VoskNif, :set_log_level, 1)
    assert function_exported?(VoskNif, :load_model, 1)
    assert function_exported?(VoskNif, :create_recognizer, 2)
    assert function_exported?(VoskNif, :accept_waveform, 2)
    assert function_exported?(VoskNif, :get_result, 1)
    assert function_exported?(VoskNif, :get_partial_result, 1)
    assert function_exported?(VoskNif, :get_final_result, 1)
  end

  test "set_log_level works" do
    # Set log level to silent
    assert VoskNif.set_log_level(-1) == :ok
    # Set log level to verbose
    assert VoskNif.set_log_level(1) == :ok
    # Reset to default
    assert VoskNif.set_log_level(0) == :ok
  end

  test "Model and Recognizer modules are loaded" do
    assert Code.ensure_loaded?(VoskNif.Model)
    assert Code.ensure_loaded?(VoskNif.Recognizer)
  end

  @tag :integration
  test "can load a valid model" do
    if File.dir?(@model_path) do
      {:ok, model} = VoskNif.Model.load(@model_path)
      assert %VoskNif.Model{ref: ref} = model
      assert is_reference(ref)
    else
      IO.puts("\nSkipping model test - model not found at #{@model_path}")
      IO.puts("Run: mix vosk.download_model")
    end
  end

  @tag :integration
  test "can create a recognizer" do
    if File.dir?(@model_path) do
      {:ok, model} = VoskNif.Model.load(@model_path)
      {:ok, recognizer} = VoskNif.Recognizer.new(model, 16000.0)
      assert %VoskNif.Recognizer{ref: ref} = recognizer
      assert is_reference(ref)
    else
      IO.puts("\nSkipping recognizer test - model not found")
    end
  end

  @tag :integration
  test "can process audio data" do
    if File.dir?(@model_path) do
      {:ok, model} = VoskNif.Model.load(@model_path)
      {:ok, recognizer} = VoskNif.Recognizer.new(model, 16000.0)

      # Create some dummy PCM audio data (silence)
      dummy_audio = <<0::16-signed-little, 0::16-signed-little>> |> String.duplicate(4000)

      # Should return :continue for silence
      result = VoskNif.Recognizer.accept_waveform(recognizer, dummy_audio)
      assert result in [:continue, :utterance_ended]

      # Should be able to get partial result
      {:ok, partial} = VoskNif.Recognizer.partial_result(recognizer)
      assert is_map(partial)
      assert Map.has_key?(partial, "partial")

      # Should be able to get final result
      {:ok, final} = VoskNif.Recognizer.final_result(recognizer)
      assert is_map(final)
      assert Map.has_key?(final, "text")
    else
      IO.puts("\nSkipping audio processing test - model not found")
    end
  end

  @tag :integration
  test "can find words in model vocabulary" do
    if File.dir?(@model_path) do
      {:ok, model} = VoskNif.Model.load(@model_path)

      # Common words should exist (returns >= 0)
      result = VoskNif.Model.find_word(model, "the")
      assert result >= 0

      # Random nonsense should not exist (returns -1)
      result = VoskNif.Model.find_word(model, "xyzqwerty123")
      assert result == -1
    else
      IO.puts("\nSkipping vocabulary test - model not found")
    end
  end
end
