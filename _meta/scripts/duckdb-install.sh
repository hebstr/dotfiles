curl https://install.duckdb.org | sh
rm "$HOME/.local/bin/duckdb"
sudo ln -sF "$HOME/.duckdb/cli/latest/duckdb" "$HOME/.local/bin/duckdb"
