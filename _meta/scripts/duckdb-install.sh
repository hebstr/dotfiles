#!/usr/bin/env bash

set -euo pipefail

BIN_DEFAULT="$HOME/.duckdb/cli/latest/duckdb"
BIN_LOCAL="$HOME/.local/bin/duckdb"
BIN_SYSTEM="/usr/local/bin/duckdb"

curl https://install.duckdb.org | sh

sudo rm "$BIN_LOCAL" "$BIN_SYSTEM"
sudo ln -sF "$BIN_DEFAULT" "$BIN_LOCAL"
sudo ln -sF "$BIN_DEFAULT" "$BIN_SYSTEM"
