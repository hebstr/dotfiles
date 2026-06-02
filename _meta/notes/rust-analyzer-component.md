# Installing the rustup rust-analyzer component

*2026-06-02T21:34:07Z by Showboat 0.6.1*
<!-- showboat-id: 415c7325-f39f-44f0-82da-45f1206e898d -->

Context: the Claude Code plugin `rust-analyzer-lsp@claude-plugins-official` launches the bare `rust-analyzer` command (via PATH). On this machine, `~/.cargo/bin/rust-analyzer` is a rustup proxy that fails because the component is not installed. Goal: install the component so the command resolves correctly.

```bash
rust-analyzer --version 2>&1 || true; echo "exit: $?"
```

```output
error: Unknown binary 'rust-analyzer' in official toolchain 'stable-x86_64-unknown-linux-gnu'.
exit: 0
```

```bash
rustup component add rust-analyzer 2>&1; echo "exit: $?"
```

```output
info: downloading component rust-analyzer
exit: 0
```

```bash
command -v rust-analyzer; rust-analyzer --version 2>&1; echo "exit: $?"; rustup component list --installed | grep rust-analyzer
```

```output
/home/julien/.cargo/bin/rust-analyzer
rust-analyzer 1.96.0 (ac68faa 2026-05-25)
exit: 0
rust-analyzer-x86_64-unknown-linux-gnu
```

Result: the `rust-analyzer-x86_64-unknown-linux-gnu` component is installed. The bare `rust-analyzer` command (PATH → `~/.cargo/bin/rust-analyzer`) now resolves to the 1.96.0 binary. The `rust-analyzer-lsp` plugin (which launches `rust-analyzer` with no configurable path) will start correctly. Note: rustup keeps the component in sync with the toolchain; no separate manual update. The Claude Code LSP may require a session restart to relaunch the server.
