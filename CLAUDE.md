# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VoskEx is an Elixir NIF (Native Implemented Function) binding for the Vosk speech recognition library. It provides offline, high-performance speech-to-text capabilities for Elixir applications.

## Build & Development Commands

### Setup
```bash
mix deps.get                 # Install dependencies
mix vosk.download_model      # Download default English model
mix vosk.download_model es   # Download Spanish model
mix vosk.download_model vosk-model-ar-0.22-linto-1.1.0  # Download custom model
```

### Building
```bash
mix compile          # Compile Elixir + C NIF (uses elixir_make)
mix clean            # Clean build artifacts (includes NIF .so file)
make clean           # Clean only C artifacts
```

### Testing
```bash
mix test                         # Run unit tests only (no model required)
mix test --include integration   # Run all tests including integration (requires model)
mix test test/vosk_nif_test.exs  # Run specific test file
MODEL_PATH=models/custom-model mix test --include integration  # Use custom model path
```

### Running Examples
```bash
elixir examples/basic_recognition.exs models/vosk-model-small-en-us-0.15 audio.wav
```

## Architecture

### Three-Layer Design

The codebase uses a layered architecture to separate concerns:

**Layer 1: C NIF (`c_src/vosk_nif.c`)**
- Direct bindings to Vosk C API via `erl_nif.h`
- Uses `ErlNifResourceType` for automatic memory management
- Critical: All Elixir string arguments must use `enif_inspect_binary()`, NOT `enif_get_string()`
- `accept_waveform` uses `ERL_NIF_DIRTY_JOB_CPU_BOUND` flag to prevent blocking BEAM schedulers

**Layer 2: Low-Level Elixir (`lib/vosk_nif.ex`)**
- Thin wrapper with NIF stub functions
- Loads shared library from `priv/vosk_nif.so`
- Module name must match C: `Elixir.VoskEx` in `ERL_NIF_INIT()`
- Returns raw data (JSON strings, integers, error atoms)

**Layer 3: High-Level API (`lib/vosk_nif/model.ex`, `lib/vosk_nif/recognizer.ex`)**
- User-facing structs wrapping resource references
- JSON parsing using Jason
- Idiomatic Elixir patterns (`{:ok, value}` / `{:error, reason}`)
- Type specs and comprehensive documentation

### Resource Management Flow

1. C allocates resource: `enif_alloc_resource(MODEL_TYPE, sizeof(ModelResource))`
2. Wrap in Erlang term: `enif_make_resource(env, res)`
3. Release C reference: `enif_release_resource(res)` (VM now owns it)
4. When GC collects: `model_destructor()` calls `vosk_model_free()`

## Critical Implementation Details

### String Handling in C
Elixir strings are UTF-8 binaries, not C strings. Always use:

```c
ErlNifBinary path_bin;
enif_inspect_binary(env, argv[0], &path_bin);
char path[1024];
memcpy(path, path_bin.data, path_bin.size);
path[path_bin.size] = '\0';  // Manual null termination required
```

**Never** use `enif_get_string()` - it expects charlists, not binaries.

### Dirty Schedulers
`accept_waveform` can take >1ms, so it MUST use dirty scheduler:

```c
{"accept_waveform", 2, accept_waveform_nif, ERL_NIF_DIRTY_JOB_CPU_BOUND}
```

Without this flag, long audio processing will block BEAM schedulers and degrade performance.

### Thread Safety
- **Models**: Can be shared across processes (reference-counted by Vosk)
- **Recognizers**: NOT thread-safe. Each GenServer should create its own recognizer instance
- Pattern: One model (shared), multiple recognizers (one per process)

### Audio Format Requirements
Vosk expects **PCM 16-bit mono** audio:
- Most common: 16000 Hz sample rate
- Binary format: Little-endian signed 16-bit integers
- WAV files: Skip 44-byte header before passing to recognizer

## Common Development Patterns

### Adding New Vosk API Functions

1. **Add C NIF function** in `c_src/vosk_nif.c`:
   ```c
   static ERL_NIF_TERM new_function_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
       // Extract arguments, call Vosk API, return result
   }
   ```

2. **Register in nif_funcs array**:
   ```c
   static ErlNifFunc nif_funcs[] = {
       {"new_function", 2, new_function_nif, 0},  // or ERL_NIF_DIRTY_JOB_CPU_BOUND
   };
   ```

3. **Add stub in `lib/vosk_nif.ex`**:
   ```elixir
   def new_function(_arg1, _arg2), do: :erlang.nif_error("NIF not loaded")
   ```

4. **Add high-level wrapper** in appropriate module:
   ```elixir
   def new_function(%__MODULE__{ref: ref}, arg) do
     VoskNif.new_function(ref, arg)
   end
   ```

5. **Recompile**: `mix clean && mix compile`

### Working with Integration Tests

Integration tests are tagged `:integration` and require a downloaded model:

```elixir
@tag :integration
test "my test" do
  if File.dir?(@model_path) do
    # Test implementation
  else
    IO.puts("\nSkipping test - run: mix vosk.download_model")
  end
end
```

The tests gracefully skip if no model is present, but you should run `mix vosk.download_model` before committing changes.

## Makefile Details

The Makefile:
- Auto-detects Erlang include path using `erl -eval`
- Links against system `libvosk.so` (installed via `vosk-api-devel` package)
- Outputs to `$(MIX_APP_PATH)/priv/` (set by Mix during compilation)
- Supports macOS via platform detection (`uname`)

If adding C source files, update `SOURCES` variable in Makefile.

## Model Management

Models are downloaded to `models/` directory (gitignored):
- Small models: ~40-50 MB, fast, less accurate
- Large models: 1-2 GB, slower, more accurate
- Downloaded via `mix vosk.download_model [language|model-name]`

The Mix task (`lib/mix/tasks/vosk.download_model.ex`):
- Uses `curl` for downloading
- Automatically extracts with `unzip`
- Supports both predefined languages and custom model names
- Model URL pattern: `https://alphacephei.com/vosk/models/{model-name}.zip`

## Debugging Tips

### NIF Loading Issues
If you see "NIF not loaded" errors:
1. Check `priv/vosk_nif.so` exists: `ls _build/dev/lib/vosk_ex/priv/`
2. Verify system libvosk: `ldconfig -p | grep vosk` (Linux) or `brew list vosk-api` (macOS)
3. Check module name matches: `ERL_NIF_INIT(Elixir.VoskEx, ...)` in C

### Compilation Errors
- Missing `vosk_api.h`: Install `vosk-api-devel` package
- Missing Erlang headers: Install `erlang-devel` package
- Makefile fails: Check `ERLANG_PATH` detection with `make -n`

### Recognition Not Working
1. Verify audio format: 16kHz, mono, PCM 16-bit
2. Check model path is correct and contains required files (`am/`, `graph/`, etc.)
3. Enable Vosk logging: `VoskEx.set_log_level(1)` to see detailed output
4. For WAV files, ensure you skip the 44-byte header

## Performance Characteristics

- **Model loading**: ~500ms one-time cost, models are cached
- **Recognizer creation**: <10ms, reuses model data
- **Audio processing**: Varies by model size and CPU, uses dirty scheduler (non-blocking)
- **Memory**: Automatic cleanup via BEAM GC, no manual management needed
- **Typical throughput**: Small models process audio faster than real-time on modern CPUs
