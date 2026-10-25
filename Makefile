# Makefile
PREFIX ?= $(HOME)/.local
BINARY = cruml
BIN_DIR = $(PREFIX)/bin
FLAGS = --release --no-debug

.PHONY: build install uninstall

build:
	shards install
	rm -rf bin
	mkdir bin
	crystal build $(FLAGS) src/$(BINARY).cr -o bin/$(BINARY)

install: build
	install -D -m 755 bin/$(BINARY) $(BIN_DIR)/$(BINARY)

uninstall:
	rm -f $(BIN_DIR)/$(BINARY)
