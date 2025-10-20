# VoskEx

[![CI](https://github.com/gonzalinux/vosk_ex/actions/workflows/ci.yaml/badge.svg)](https://github.com/gonzalinux/vosk_ex/actions/workflows/ci.yaml)
[![Hex.pm](https://img.shields.io/hexpm/v/vosk_ex.svg)](https://hex.pm/packages/vosk_ex)
[![Documentation](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/vosk_ex)

Elixir bindings for the [Vosk API](https://alphacephei.com/vosk/) - offline speech recognition toolkit.

VoskEx provides a high-performance interface to Vosk's speech recognition capabilities, allowing you to recognize speech from audio files or streams entirely offline, with no network connection required.

## Features

- 🎯 **Offline speech recognition** - No cloud APIs required
- 🚀 **High performance** - Uses NIF for direct C library integration
- 🔄 **Streaming support** - Process audio in real-time or from files
- 🌍 **Multi-language** - Support for 20+ languages via Vosk models
- 📊 **Detailed results** - Get word-level timing and confidence scores
- 🧵 **Thread-safe** - Uses dirty schedulers for non-blocking operation

## Installation

VoskEx automatically downloads precompiled Vosk libraries during compilation, so **no system dependencies are required**!

Simply add `vosk_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vosk_ex, "~> 0.2.0"}
  ]
end
```

Then run:
```bash
mix deps.get
mix compile  # Automatically downloads Vosk library (~2-7 MB) for your platform
```

Supported platforms:
- **Linux**: x86_64, aarch64 (ARM64)
- **macOS**: Intel (x86_64), Apple Silicon (M1/M2/M3)
- **Windows**: x64

The library automatically detects your platform and downloads the appropriate precompiled Vosk library on first compilation.

### Windows Users - Additional Setup Required

On Windows, you need to add the Vosk DLL directory to PATH **before** starting your application. This is a Windows limitation for finding external DLL dependencies.

**Why?** Unlike bcrypt or other self-contained NIFs, VoskEx depends on external Vosk DLLs (26MB+ of speech recognition libraries). Windows needs to know where to find these at runtime.

**Option 1 - Set PATH manually (PowerShell):**
```powershell
# In PowerShell, before running your app
$env:PATH = "_build\dev\lib\vosk_ex\priv\native\windows-x86_64;$env:PATH"

# Then run normally
mix test
mix run
iex -S mix
```

**Option 2 - Use the included helper script:**
```powershell
# Copy scripts/windows/run.ps1 to your project root
.\scripts\windows\run.ps1 mix test
.\scripts\windows\run.ps1 iex -S mix
```

**Option 3 - Create a startup script for your app:**
```powershell
# my_app.ps1
$env:PATH = "_build\dev\lib\vosk_ex\priv\native\windows-x86_64;$env:PATH"
mix run --no-halt
```

**Option 4 - Use Mix releases (recommended for production):**
```bash
mix release
# Releases automatically bundle all DLLs - no PATH manipulation needed!
```

**Note:** For test environment, use `_build\test\lib\vosk_ex\priv\native\windows-x86_64` instead.

## Configuration

VoskEx logs are **disabled by default**. To enable Vosk/Kaldi internal logging, add to your `config/config.exs`:

```elixir
config :vosk_ex,
  log_level: 0  # -1 = silent (default), 0 = default logging, >0 = more verbose
```

## Usage

### 1. Download a speech model

Use the built-in Mix task to download a model:

```bash
# Download default English model
mix vosk.download_model

# Download Spanish model
mix vosk.download_model es

# Download specific model by name
mix vosk.download_model vosk-model-small-en-us-0.15
```

Available predefined languages: `en-us`, `es`, `fr`, `de`, `ru`, `cn`, `ja`, `pt`, `it`, and more.

Or download manually from [https://alphacephei.com/vosk/models](https://alphacephei.com/vosk/models).

### 2. Basic usage

```elixir
# Load the model
{:ok, model} = VoskEx.Model.load("vosk-model-small-en-us-0.15")

# Create a recognizer (16kHz sample rate)
{:ok, recognizer} = VoskEx.Recognizer.new(model, 16000.0)

# Optional: Enable word timing
:ok = VoskEx.Recognizer.set_words(recognizer, true)

# Read audio file (PCM 16-bit mono, skip WAV header)
audio = File.read!("audio.wav") |> binary_part(44, byte_size(audio) - 44)

# Process audio in chunks
chunk_size = 8000
for <<chunk::binary-size(chunk_size) <- audio>> do
  case VoskEx.Recognizer.accept_waveform(recognizer, chunk) do
    :utterance_ended ->
      {:ok, result} = VoskEx.Recognizer.result(recognizer)
      IO.inspect(result)

    :continue ->
      {:ok, partial} = VoskEx.Recognizer.partial_result(recognizer)
      IO.inspect(partial, label: "Partial")
  end
end

# Get final result
{:ok, final} = VoskEx.Recognizer.final_result(recognizer)
IO.inspect(final, label: "Final")
```

### 3. Result format

```elixir
# Simple result
%{"text" => "hello world"}

# With word timing (when set_words is enabled)
%{
  "result" => [
    %{"conf" => 1.0, "end" => 1.110000, "start" => 0.870000, "word" => "hello"},
    %{"conf" => 0.98, "end" => 1.530000, "start" => 1.110000, "word" => "world"}
  ],
  "text" => "hello world"
}

# Partial result
%{"partial" => "hello wor"}
```

### 4. Streaming audio

```elixir
defmodule AudioProcessor do
  use GenServer

  def start_link(model_path) do
    GenServer.start_link(__MODULE__, model_path)
  end

  def init(model_path) do
    {:ok, model} = VoskEx.Model.load(model_path)
    {:ok, recognizer} = VoskEx.Recognizer.new(model, 16000.0)
    VoskEx.Recognizer.set_words(recognizer, true)

    {:ok, %{model: model, recognizer: recognizer}}
  end

  def handle_call({:process_audio, audio_chunk}, _from, state) do
    result = case VoskEx.Recognizer.accept_waveform(state.recognizer, audio_chunk) do
      :utterance_ended ->
        {:ok, result} = VoskEx.Recognizer.result(state.recognizer)
        {:utterance, result}

      :continue ->
        {:ok, partial} = VoskEx.Recognizer.partial_result(state.recognizer)
        {:partial, partial}

      :error ->
        {:error, :recognition_failed}
    end

    {:reply, result, state}
  end
end
```

## Documentation

Full documentation is available at [https://hexdocs.pm/vosk_ex](https://hexdocs.pm/vosk_ex) or you can generate it locally:

```bash
mix docs
open doc/index.html
```

## API Reference

### VoskEx.Model

- `load(path)` - Load a model from a directory
- `load!(path)` - Load a model, raising on error
- `find_word(model, word)` - Check if a word exists in vocabulary

### VoskEx.Recognizer

- `new(model, sample_rate)` - Create a recognizer
- `new!(model, sample_rate)` - Create a recognizer, raising on error
- `set_max_alternatives(recognizer, max)` - Set number of alternatives
- `set_words(recognizer, enabled)` - Enable word timing in results
- `set_partial_words(recognizer, enabled)` - Enable word timing in partial results
- `accept_waveform(recognizer, audio)` - Process audio data
- `result(recognizer)` - Get final result
- `partial_result(recognizer)` - Get partial result
- `final_result(recognizer)` - Get final result at stream end
- `reset(recognizer)` - Reset recognizer state

### VoskEx (Low-level API)

- `set_log_level(level)` - Set Vosk/Kaldi logging level (-1 = silent, 0 = default, >0 = verbose)

## Audio Format

Vosk expects **PCM 16-bit mono** audio. Sample rates typically used:
- 8000 Hz - Telephone quality
- 16000 Hz - Standard quality (most models)
- 44100 Hz - CD quality (if model supports it)

### Converting audio with ffmpeg

```bash
# Convert any audio to 16kHz mono PCM WAV
ffmpeg -i input.mp3 -ar 16000 -ac 1 -f wav output.wav

# Extract raw PCM (no WAV header)
ffmpeg -i input.mp3 -ar 16000 -ac 1 -f s16le output.raw
```

## Performance Considerations

- **Model size**: Larger models are more accurate but slower
  - Small models: ~50 MB, fast, less accurate
  - Large models: 1-2 GB, slower, more accurate
- **Dirty schedulers**: `accept_waveform` uses dirty CPU schedulers to avoid blocking BEAM
- **Memory management**: Models and recognizers are automatically freed by the garbage collector
- **Thread safety**: Models can be shared, but each GenServer should have its own recognizer

## Available Models

Download models from [https://alphacephei.com/vosk/models](https://alphacephei.com/vosk/models)

Languages include:
- English (US, UK, Indian)
- Chinese, Japanese, Korean
- Spanish, French, German, Italian, Portuguese
- Russian, Ukrainian, Polish, Czech
- And many more...

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

Vosk itself is licensed under the Apache License 2.0.

## Acknowledgments

- [Vosk Speech Recognition Toolkit](https://alphacephei.com/vosk/)
- [Alpha Cephei](https://alphacephei.com/) for developing Vosk
