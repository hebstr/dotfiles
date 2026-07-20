# Lua toolchain install: StyLua + lua-language-server

*2026-07-20T15:13:52Z by Showboat 0.6.1*
<!-- showboat-id: b484c009-0742-44a0-87b8-ac664810307a -->

Installs the two binaries backing the Lua lint/format gate (`rules/lua.md`).
StyLua is a single prebuilt binary; lua-language-server ships as a runtime tree with a launcher script.
Both from upstream GitHub releases (apt lags), pinned: StyLua v2.5.2, lua-language-server 3.18.2, linux x86_64/x64.
Targets `~/.local/bin` (already on PATH).

## StyLua v2.5.2 --- download, extract, install to ~/.local/bin

```bash
set -euo pipefail
ver=v2.5.2
tmp=$(mktemp -d)
curl -sSL -o "$tmp/stylua.zip" "https://github.com/JohnnyMorganz/StyLua/releases/download/${ver}/stylua-linux-x86_64.zip"
unzip -o -q "$tmp/stylua.zip" -d "$tmp"
install -m 0755 "$tmp/stylua" "$HOME/.local/bin/stylua"
rm -rf "$tmp"
command -v stylua
stylua --version
```

```output
/home/julien/.local/bin/stylua
stylua 2.5.2
```

## lua-language-server 3.18.2 --- extract runtime to ~/.local/share, symlink launcher into ~/.local/bin

```bash
set -euo pipefail
ver=3.18.2
dest="$HOME/.local/share/lua-language-server"
tmp=$(mktemp -d)
curl -sSL -o "$tmp/luals.tar.gz" "https://github.com/LuaLS/lua-language-server/releases/download/${ver}/lua-language-server-${ver}-linux-x64.tar.gz"
rm -rf "$dest"; mkdir -p "$dest"
tar -xzf "$tmp/luals.tar.gz" -C "$dest"
rm -rf "$tmp"
ln -sf "$dest/bin/lua-language-server" "$HOME/.local/bin/lua-language-server"
command -v lua-language-server
lua-language-server --version
```

```output
/home/julien/.local/bin/lua-language-server
3.18.2-dev
```

Install locations: `stylua` → `~/.local/bin/stylua` (self-contained binary); `lua-language-server` runtime → `~/.local/share/lua-language-server/` with a launcher symlink at `~/.local/bin/lua-language-server`.
LuaLS self-reports `3.18.2-dev` --- that is the upstream build string for the 3.18.2 release tag, not a nightly.
Rows added to `rules/environment.md`.

Next: wire `.luarc.json` + vendored LuaCATS stubs in quarto-hebstr-doc (PLAN-LUA step 2).
