# Detect Erlang paths
ERLANG_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)

# Compiler flags
CFLAGS = -O3 -std=c11 -fPIC -I$(ERLANG_PATH) -I/usr/include
LDFLAGS = -shared -L/usr/lib64 -lvosk

# Platform-specific adjustments
ifeq ($(shell uname),Darwin)
    LDFLAGS += -undefined dynamic_lookup -flat_namespace
endif

# Directories
BUILD_DIR = $(MIX_APP_PATH)/priv
TARGET = $(BUILD_DIR)/vosk_nif.so
SOURCES = c_src/vosk_nif.c

# Build target
all: $(BUILD_DIR) $(TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(TARGET): $(SOURCES)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SOURCES)

clean:
	rm -f $(TARGET)

.PHONY: all clean
