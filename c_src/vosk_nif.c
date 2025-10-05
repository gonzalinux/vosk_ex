#include <erl_nif.h>
#include <vosk_api.h>
#include <string.h>

// Resource types
static ErlNifResourceType* MODEL_TYPE;
static ErlNifResourceType* RECOGNIZER_TYPE;

// Resource structures
typedef struct {
    VoskModel* model;
} ModelResource;

typedef struct {
    VoskRecognizer* recognizer;
} RecognizerResource;

// Resource destructors
static void model_destructor(ErlNifEnv* env, void* obj) {
    ModelResource* res = (ModelResource*)obj;
    if (res->model != NULL) {
        vosk_model_free(res->model);
        res->model = NULL;
    }
}

static void recognizer_destructor(ErlNifEnv* env, void* obj) {
    RecognizerResource* res = (RecognizerResource*)obj;
    if (res->recognizer != NULL) {
        vosk_recognizer_free(res->recognizer);
        res->recognizer = NULL;
    }
}

// Helper function to make error tuples
static ERL_NIF_TERM make_error(ErlNifEnv* env, const char* reason) {
    return enif_make_tuple2(env,
        enif_make_atom(env, "error"),
        enif_make_atom(env, reason));
}

// Set log level
static ERL_NIF_TERM set_log_level_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    int level;
    if (!enif_get_int(env, argv[0], &level)) {
        return enif_make_badarg(env);
    }

    vosk_set_log_level(level);
    return enif_make_atom(env, "ok");
}

// Load model
static ERL_NIF_TERM load_model_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ErlNifBinary path_bin;
    if (!enif_inspect_binary(env, argv[0], &path_bin)) {
        return enif_make_badarg(env);
    }

    // Ensure null termination
    char path[1024];
    if (path_bin.size >= sizeof(path)) {
        return enif_make_badarg(env);
    }
    memcpy(path, path_bin.data, path_bin.size);
    path[path_bin.size] = '\0';

    VoskModel* model = vosk_model_new(path);
    if (model == NULL) {
        return make_error(env, "model_load_failed");
    }

    ModelResource* res = enif_alloc_resource(MODEL_TYPE, sizeof(ModelResource));
    res->model = model;

    ERL_NIF_TERM term = enif_make_resource(env, res);
    enif_release_resource(res);

    return enif_make_tuple2(env, enif_make_atom(env, "ok"), term);
}

// Find word in model
static ERL_NIF_TERM find_word_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ModelResource* model_res;
    ErlNifBinary word_bin;

    if (!enif_get_resource(env, argv[0], MODEL_TYPE, (void**)&model_res) ||
        !enif_inspect_binary(env, argv[1], &word_bin)) {
        return enif_make_badarg(env);
    }

    // Ensure null termination
    char word[256];
    if (word_bin.size >= sizeof(word)) {
        return enif_make_badarg(env);
    }
    memcpy(word, word_bin.data, word_bin.size);
    word[word_bin.size] = '\0';

    int result = vosk_model_find_word(model_res->model, word);
    return enif_make_int(env, result);
}

// Create recognizer
static ERL_NIF_TERM create_recognizer_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    ModelResource* model_res;
    double sample_rate;

    if (!enif_get_resource(env, argv[0], MODEL_TYPE, (void**)&model_res) ||
        !enif_get_double(env, argv[1], &sample_rate)) {
        return enif_make_badarg(env);
    }

    VoskRecognizer* rec = vosk_recognizer_new(model_res->model, (float)sample_rate);
    if (rec == NULL) {
        return make_error(env, "recognizer_creation_failed");
    }

    RecognizerResource* res = enif_alloc_resource(RECOGNIZER_TYPE, sizeof(RecognizerResource));
    res->recognizer = rec;

    ERL_NIF_TERM term = enif_make_resource(env, res);
    enif_release_resource(res);

    return enif_make_tuple2(env, enif_make_atom(env, "ok"), term);
}

// Set max alternatives
static ERL_NIF_TERM set_max_alternatives_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    RecognizerResource* rec_res;
    int max_alternatives;

    if (!enif_get_resource(env, argv[0], RECOGNIZER_TYPE, (void**)&rec_res) ||
        !enif_get_int(env, argv[1], &max_alternatives)) {
        return enif_make_badarg(env);
    }

    vosk_recognizer_set_max_alternatives(rec_res->recognizer, max_alternatives);
    return enif_make_atom(env, "ok");
}

// Set words
static ERL_NIF_TERM set_words_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    RecognizerResource* rec_res;
    int words;

    if (!enif_get_resource(env, argv[0], RECOGNIZER_TYPE, (void**)&rec_res) ||
        !enif_get_int(env, argv[1], &words)) {
        return enif_make_badarg(env);
    }

    vosk_recognizer_set_words(rec_res->recognizer, words);
    return enif_make_atom(env, "ok");
}

// Set partial words
static ERL_NIF_TERM set_partial_words_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    RecognizerResource* rec_res;
    int partial_words;

    if (!enif_get_resource(env, argv[0], RECOGNIZER_TYPE, (void**)&rec_res) ||
        !enif_get_int(env, argv[1], &partial_words)) {
        return enif_make_badarg(env);
    }

    vosk_recognizer_set_partial_words(rec_res->recognizer, partial_words);
    return enif_make_atom(env, "ok");
}

// Accept waveform (dirty NIF for potentially long operation)
static ERL_NIF_TERM accept_waveform_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    RecognizerResource* rec_res;
    ErlNifBinary audio_data;

    if (!enif_get_resource(env, argv[0], RECOGNIZER_TYPE, (void**)&rec_res) ||
        !enif_inspect_binary(env, argv[1], &audio_data)) {
        return enif_make_badarg(env);
    }

    int result = vosk_recognizer_accept_waveform(
        rec_res->recognizer,
        (const char*)audio_data.data,
        audio_data.size
    );

    return enif_make_int(env, result);
}

// Get result
static ERL_NIF_TERM get_result_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    RecognizerResource* rec_res;

    if (!enif_get_resource(env, argv[0], RECOGNIZER_TYPE, (void**)&rec_res)) {
        return enif_make_badarg(env);
    }

    const char* result = vosk_recognizer_result(rec_res->recognizer);
    return enif_make_string(env, result, ERL_NIF_UTF8);
}

// Get partial result
static ERL_NIF_TERM get_partial_result_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    RecognizerResource* rec_res;

    if (!enif_get_resource(env, argv[0], RECOGNIZER_TYPE, (void**)&rec_res)) {
        return enif_make_badarg(env);
    }

    const char* result = vosk_recognizer_partial_result(rec_res->recognizer);
    return enif_make_string(env, result, ERL_NIF_UTF8);
}

// Get final result
static ERL_NIF_TERM get_final_result_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    RecognizerResource* rec_res;

    if (!enif_get_resource(env, argv[0], RECOGNIZER_TYPE, (void**)&rec_res)) {
        return enif_make_badarg(env);
    }

    const char* result = vosk_recognizer_final_result(rec_res->recognizer);
    return enif_make_string(env, result, ERL_NIF_UTF8);
}

// Reset recognizer
static ERL_NIF_TERM reset_recognizer_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    RecognizerResource* rec_res;

    if (!enif_get_resource(env, argv[0], RECOGNIZER_TYPE, (void**)&rec_res)) {
        return enif_make_badarg(env);
    }

    vosk_recognizer_reset(rec_res->recognizer);
    return enif_make_atom(env, "ok");
}

// NIF initialization callback
static int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {
    // Set log level from load_info parameter (passed from Elixir)
    // Default to -1 (silent) if not an integer
    int log_level = -1;
    if (!enif_get_int(env, load_info, &log_level)) {
        log_level = -1;  // Default to silent if invalid
    }
    vosk_set_log_level(log_level);

    MODEL_TYPE = enif_open_resource_type(
        env, NULL, "VoskModel",
        model_destructor,
        ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER,
        NULL
    );

    RECOGNIZER_TYPE = enif_open_resource_type(
        env, NULL, "VoskRecognizer",
        recognizer_destructor,
        ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER,
        NULL
    );

    if (MODEL_TYPE == NULL || RECOGNIZER_TYPE == NULL) {
        return 1;
    }

    return 0;
}

// NIF function exports
static ErlNifFunc nif_funcs[] = {
    {"set_log_level", 1, set_log_level_nif, 0},
    {"load_model", 1, load_model_nif, 0},
    {"find_word", 2, find_word_nif, 0},
    {"create_recognizer", 2, create_recognizer_nif, 0},
    {"set_max_alternatives", 2, set_max_alternatives_nif, 0},
    {"set_words", 2, set_words_nif, 0},
    {"set_partial_words", 2, set_partial_words_nif, 0},
    {"accept_waveform", 2, accept_waveform_nif, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"get_result", 1, get_result_nif, 0},
    {"get_partial_result", 1, get_partial_result_nif, 0},
    {"get_final_result", 1, get_final_result_nif, 0},
    {"reset_recognizer", 1, reset_recognizer_nif, 0}
};

// Initialize NIF module
ERL_NIF_INIT(Elixir.VoskEx, nif_funcs, load, NULL, NULL, NULL)
