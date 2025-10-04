# VoskNif

Elixir NIF bindings for [Vosk](https://alphacephei.com/vosk/), an offline speech recognition toolkit.

VoskNif provides a high-performance interface to Vosk's speech recognition capabilities, allowing you to recognize speech from audio files or streams entirely offline, with no network connection required.

## Features

- 🎯 **Offline speech recognition** - No cloud APIs required
- 🚀 **High performance** - Uses NIF for direct C library integration
- 🔄 **Streaming support** - Process audio in real-time or from files
- 🌍 **Multi-language** - Support for 20+ languages via Vosk models
- 📊 **Detailed results** - Get word-level timing and confidence scores
- 🧵 **Thread-safe** - Uses dirty schedulers for non-blocking operation

## Prerequisites

### Fedora 42

```bash
sudo dnf install vosk-api-devel
```

### Other Linux distributions

Either install vosk-api-devel from your package manager, or build from source. See the [Vosk documentation](https://alphacephei.com/vosk/install) for details.

### macOS

```bash
brew install vosk-api
```

## Installation

Add `vosk_nif` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vosk_nif, "~> 0.1.0"}
  ]
end
```

## Usage

### 1. Download a speech model

Download a model from [https://alphacephei.com/vosk/models](https://alphacephei.com/vosk/models):

```bash
wget https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
unzip vosk-model-small-en-us-0.15.zip
```

### 2. Basic usage

```elixir
# Load the model
{:ok, model} = VoskNif.Model.load("vosk-model-small-en-us-0.15")

# Create a recognizer (16kHz sample rate)
{:ok, recognizer} = VoskNif.Recognizer.new(model, 16000.0)

# Optional: Enable word timing
:ok = VoskNif.Recognizer.set_words(recognizer, true)

# Read audio file (PCM 16-bit mono, skip WAV header)
audio = File.read!("audio.wav") |> binary_part(44, byte_size(audio) - 44)

# Process audio in chunks
chunk_size = 8000
for <<chunk::binary-size(chunk_size) <- audio>> do
  case VoskNif.Recognizer.accept_waveform(recognizer, chunk) do
    :utterance_ended ->
      {:ok, result} = VoskNif.Recognizer.result(recognizer)
      IO.inspect(result)

    :continue ->
      {:ok, partial} = VoskNif.Recognizer.partial_result(recognizer)
      IO.inspect(partial, label: "Partial")
  end
end

# Get final result
{:ok, final} = VoskNif.Recognizer.final_result(recognizer)
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
    {:ok, model} = VoskNif.Model.load(model_path)
    {:ok, recognizer} = VoskNif.Recognizer.new(model, 16000.0)
    VoskNif.Recognizer.set_words(recognizer, true)

    {:ok, %{model: model, recognizer: recognizer}}
  end

  def handle_call({:process_audio, audio_chunk}, _from, state) do
    result = case VoskNif.Recognizer.accept_waveform(state.recognizer, audio_chunk) do
      :utterance_ended ->
        {:ok, result} = VoskNif.Recognizer.result(state.recognizer)
        {:utterance, result}

      :continue ->
        {:ok, partial} = VoskNif.Recognizer.partial_result(state.recognizer)
        {:partial, partial}

      :error ->
        {:error, :recognition_failed}
    end

    {:reply, result, state}
  end
end
```

## API Reference

### VoskNif.Model

- `load(path)` - Load a model from a directory
- `load!(path)` - Load a model, raising on error
- `find_word(model, word)` - Check if a word exists in vocabulary

### VoskNif.Recognizer

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

### VoskNif (Low-level API)

- `set_log_level(level)` - Set Vosk/Kaldi logging level (0 = default, <0 = silent, >0 = verbose)

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
