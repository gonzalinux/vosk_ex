# Detect Erlang paths
ERLANG_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)

# Detect platform
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Platform-specific settings
ifeq ($(UNAME_S),Linux)
    ifeq ($(UNAME_M),x86_64)
        NATIVE_DIR = linux-x86_64
        LIB_EXT = so
    else ifeq ($(UNAME_M),aarch64)
        NATIVE_DIR = linux-aarch64
        LIB_EXT = so
    else
        $(error Unsupported Linux architecture: $(UNAME_M))
    endif
else ifeq ($(UNAME_S),Darwin)
    # macOS uses Linux builds (they work via compatibility)
    ifeq ($(UNAME_M),x86_64)
        NATIVE_DIR = linux-x86_64
        LIB_EXT = so
    else ifeq ($(UNAME_M),arm64)
        NATIVE_DIR = linux-aarch64
        LIB_EXT = so
    else
        $(error Unsupported macOS architecture: $(UNAME_M))
    endif
else ifeq ($(OS),Windows_NT)
    NATIVE_DIR = windows-x86_64
    LIB_EXT = dll
else
    $(error Unsupported platform: $(UNAME_S))
endif

# Directories
BUILD_DIR = $(MIX_APP_PATH)/priv
NATIVE_LIB_DIR = priv/native/$(NATIVE_DIR)
TARGET = $(BUILD_DIR)/vosk_nif.so
SOURCES = c_src/vosk_nif.c

# Compiler flags using bundled library
CFLAGS = -O3 -std=c11 -fPIC -I$(ERLANG_PATH) -Ic_src/include
LDFLAGS = -shared -L$(NATIVE_LIB_DIR) -lvosk -Wl,-rpath,'$$ORIGIN/native/$(NATIVE_DIR)'

# Platform-specific adjustments
ifeq ($(UNAME_S),Darwin)
    LDFLAGS += -undefined dynamic_lookup -flat_namespace
    LDFLAGS := $(filter-out -Wl$(comma)-rpath$(comma)'$$ORIGIN/native/$(NATIVE_DIR)',$(LDFLAGS))
    LDFLAGS += -Wl,-rpath,@loader_path/native/$(NATIVE_DIR)
endif

# Vosk library download settings
VOSK_VERSION = 0.3.45
BASE_URL = https://github.com/alphacep/vosk-api/releases/download/v$(VOSK_VERSION)

ifeq ($(NATIVE_DIR),linux-x86_64)
    VOSK_DOWNLOAD = vosk-linux-x86_64-$(VOSK_VERSION).zip
else ifeq ($(NATIVE_DIR),linux-aarch64)
    VOSK_DOWNLOAD = vosk-linux-aarch64-$(VOSK_VERSION).zip
else ifeq ($(NATIVE_DIR),windows-x86_64)
    VOSK_DOWNLOAD = vosk-win64-$(VOSK_VERSION).zip
endif

# Build target
all: $(NATIVE_LIB_DIR)/libvosk.$(LIB_EXT) $(BUILD_DIR) $(TARGET)

# Download Vosk library if not present
$(NATIVE_LIB_DIR)/libvosk.$(LIB_EXT):
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Downloading Vosk library for $(NATIVE_DIR)..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@mkdir -p $(NATIVE_LIB_DIR)
	@TMP_DIR=$$(mktemp -d) && \
	echo "URL: $(BASE_URL)/$(VOSK_DOWNLOAD)" && \
	echo "Downloading..." && \
	curl -L --progress-bar -o $$TMP_DIR/$(VOSK_DOWNLOAD) $(BASE_URL)/$(VOSK_DOWNLOAD) && \
	echo "Extracting..." && \
	unzip -q -o $$TMP_DIR/$(VOSK_DOWNLOAD) -d $$TMP_DIR && \
	EXTRACTED_DIR=$$(find $$TMP_DIR -maxdepth 1 -type d -name "vosk-*" | head -1) && \
	cp $$EXTRACTED_DIR/libvosk.$(LIB_EXT) $(NATIVE_LIB_DIR)/ && \
	rm -rf $$TMP_DIR && \
	echo "✓ Library installed to $(NATIVE_LIB_DIR)/" && \
	echo ""

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(TARGET): $(SOURCES) $(NATIVE_LIB_DIR)/libvosk.$(LIB_EXT)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SOURCES)

clean:
	rm -f $(TARGET)

.PHONY: all clean
