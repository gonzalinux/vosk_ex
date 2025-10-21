defmodule VoskEx do
  @moduledoc """
  Elixir bindings for the Vosk API speech recognition library.

  VoskEx provides offline, high-performance speech-to-text capabilities for Elixir applications
  through bindings to the [Vosk API](https://alphacephei.com/vosk/).

  ## Installation

  Add `vosk_ex` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [
      {:vosk_ex, "~> 0.1.0"}
    ]
  end
  ```

  VoskEx automatically downloads precompiled Vosk libraries during compilation, so **no system dependencies are required**!

  Simply run:
  ```bash
  mix deps.get
  mix compile  # Automatically downloads Vosk library (~2-7 MB) for your platform
  ```

  Supported platforms:
  - **Linux**: x86_64, aarch64 (ARM64)
  - **macOS**: Intel (x86_64), Apple Silicon (M1/M2/M3)
  - **Windows**: x64

  ## Configuration

  VoskEx logs are **disabled by default** to keep your application logs clean.
  To enable Vosk/Kaldi internal logging, add to your `config/config.exs`:

  ```elixir
  config :vosk_ex,
    log_level: 0  # -1 = silent (default), 0 = default logging, >0 = more verbose
  ```

  ## Quick Start

  ```elixir
  # Download a model first
  Mix.Task.run("vosk.download_model", ["en"])

  # Load model and create recognizer
  {:ok, model} = VoskEx.Model.load("models/vosk-model-small-en-us-0.15")
  {:ok, recognizer} = VoskEx.Recognizer.new(model, 16000.0)

  # Process audio (PCM 16-bit mono)
  audio = File.read!("audio.wav") |> binary_part(44, byte_size(audio) - 44)
  case VoskEx.Recognizer.accept_waveform(recognizer, audio) do
    :utterance_ended ->
      {:ok, result} = VoskEx.Recognizer.result(recognizer)
      IO.inspect(result["text"])
    :continue ->
      {:ok, partial} = VoskEx.Recognizer.partial_result(recognizer)
      IO.inspect(partial["partial"])
  end
  ```

  ## Architecture

  This module provides low-level bindings to the Vosk C API.
  For a more user-friendly interface, use `VoskEx.Model` and `VoskEx.Recognizer`.

  The library uses a three-layer architecture:
  - **Layer 1 (C NIF)**: Direct bindings to Vosk C API via `erl_nif.h`
  - **Layer 2 (Low-Level)**: This module - thin Elixir wrapper with NIF stubs
  - **Layer 3 (High-Level)**: `VoskEx.Model` and `VoskEx.Recognizer` - idiomatic Elixir API

  Resources are automatically managed through BEAM garbage collection.
  """

  @on_load :load_nifs

  def load_nifs do
    # Set up library path for bundled libvosk
    priv_dir = :code.priv_dir(:vosk_ex)
    native_dir = :filename.join([priv_dir, ~c"native", detect_platform()])

    # Add native library directory to LD_LIBRARY_PATH equivalent
    case :os.type() do
      {:unix, :darwin} ->
        # macOS uses DYLD_LIBRARY_PATH but it's restricted, rpath should work
        :ok

      {:unix, _} ->
        # Linux - add to LD_LIBRARY_PATH
        current_path = System.get_env("LD_LIBRARY_PATH", "")

        new_path =
          if current_path == "",
            do: List.to_string(native_dir),
            else: "#{List.to_string(native_dir)}:#{current_path}"

        System.put_env("LD_LIBRARY_PATH", new_path)

      {:win32, _} ->
        # Windows: PATH must be set before starting Erlang/Elixir
        # See README.md "Windows Users - Additional Setup Required" section
        :ok
    end

    # On Windows, NIF is in native directory alongside DLLs for dependency resolution
    nif_file =
      case :os.type() do
        {:win32, _} -> :filename.join([priv_dir, ~c"native", detect_platform(), ~c"vosk_nif"])
        _ -> :filename.join(priv_dir, ~c"vosk_nif")
      end

    # Get log level from application config, default to -1 (silent)
    log_level = Application.get_env(:vosk_ex, :log_level, -1)

    case :erlang.load_nif(nif_file, log_level) do
      :ok ->
        :ok

      {:error, {:load_failed, reason}} ->
        IO.warn("Failed to load NIF: #{inspect(reason)}")
        IO.warn("Native library directory: #{native_dir}")
        :ok
    end
  end

  defp detect_platform do
    case :os.type() do
      {:unix, :linux} ->
        detect_arch()

      {:unix, :darwin} ->
        # macOS uses Linux builds (they work via compatibility)
        detect_arch()

      {:win32, _} ->
        ~c"windows-x86_64"
    end
  end

  defp detect_arch do
    case :erlang.system_info(:system_architecture) do
      arch when is_list(arch) ->
        arch_str = List.to_string(arch)

        cond do
          String.contains?(arch_str, "x86_64") or String.contains?(arch_str, "amd64") ->
            ~c"linux-x86_64"

          String.contains?(arch_str, "aarch64") or String.contains?(arch_str, "arm64") ->
            ~c"linux-aarch64"

          true ->
            # default
            ~c"linux-x86_64"
        end
    end
  end

  # NIF stub functions (replaced at runtime)

  @doc """
  Set the log level for Vosk/Kaldi messages.

  - -1: silent
  - 0: default logging
  - > 0: more verbose
  """
  def set_log_level(_level), do: :erlang.nif_error("NIF not loaded")

  @doc """
  Load a Vosk model from a directory path.

  Returns `{:ok, model_ref}` or `{:error, :model_load_failed}`.
  """
  def load_model(_path), do: :erlang.nif_error("NIF not loaded")

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
