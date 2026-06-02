---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/rustfmt.toml"
  - "**/clippy.toml"
  - "**/rust-toolchain.toml"
---

# Rust toolchain

## Code style conventions

- Edition: default new projects to the latest stable edition (2024 as of rustc 1.85+); set `edition` explicitly in `Cargo.toml`. Editions are opt-in and interoperate across crates.
- Naming (RFC 430): `UpperCamelCase` for types, traits, enum variants; `snake_case` for modules, functions, methods, variables; `SCREAMING_SNAKE_CASE` for constants and statics. Acronyms count as one word (`Uuid`, not `UUID`).
- Prefer borrowing (`&T`) over moving or cloning; take ownership only when genuinely needed. Treat a proliferation of `.clone()` to silence the borrow checker as a smell, not a fix.
- `String` (owned, heap) vs `&str` (borrowed view): take `&str` as function arguments, return/store `String` when ownership is required.
- Iterators over manual indexed loops (`.iter().map().filter().collect()`, `for x in &collection`); clippy enforces this, but its suggestions are advisory, not law.
- Lean on `match` exhaustiveness; use `if let` / `let else` for single-variant cases.
- Derive traits (`#[derive(Debug, Clone, PartialEq, ...)]`) rather than hand-writing impls.

## Error handling

- `Result` / `Option` + the `?` operator for propagation. `Option` for "absence is normal", `Result` for "can fail with a reason".
- Applications / binaries use `anyhow` (type-erased, `.context(...)`). Libraries use `thiserror` (matchable error enums via `#[derive(Error)]`). Both together is a recognized pattern: lib modules define types with `thiserror`, `main.rs` aggregates with `anyhow`.
- `unwrap()` / `expect()`: fine in tests, prototypes, and learning code. In code meant to last, prefer `expect("why this can't fail")` over bare `unwrap()`.

## CLI tools

| Tool | Role |
|---|---|
| `cargo fmt` (rustfmt) | Formatter (cosmetic, no semantic change) |
| `cargo clippy` | Linter (>800 lints; superset of `cargo check`, compiles then lints) |
| `cargo check` | Fast validity check, no binary codegen (fastest feedback loop) |
| `cargo test` | Test runner |
| `bacon` | Background checker; re-runs `cargo check`/`clippy`/`test` on save (`cargo install bacon`) |

`cargo add <crate>` is built into Cargo (no `cargo-edit` needed for it).

## Mandatory pipeline after every create/edit

```sh
cargo fmt && cargo clippy --all-targets && cargo test
```

Order: `cargo fmt` first (formats in place), then `cargo clippy` (reports idiom/correctness lints; it compiles, so a separate `cargo check` in the gate is redundant), then tests last. clippy runs in **report mode** by default: read each lint's rationale and fix idiomatically rather than auto-applying. `cargo clippy --fix` exists for batch auto-fix but requires a clean VCS tree (`--allow-dirty` otherwise) and rewrites logic, so it is opt-in, not the default gate; if you do use it, re-run the gate afterward (it rewrote code, so re-format, re-lint, and re-test).

Stay on default clippy. Do **not** gate on `clippy::pedantic` (false-positive prone); use it occasionally as an idiom teacher, never as a build gate. A clippy *warning* does not fail the gate (only compile errors do, or `-D warnings`, which is not set by default): apply idiomatic fixes where the lint is correct, but residual advisory warnings do not block reporting the task done.

## Useful flags

**cargo fmt**

| Flag | Effect |
|---|---|
| `--check` | Dry-run, exits non-zero if a file would change |

**cargo clippy**

| Flag | Effect |
|---|---|
| `--all-targets` | Lint tests, examples, benches too (part of the mandatory gate, not optional) |
| `--fix` | Auto-apply machine-applicable suggestions (needs clean VCS tree; implies `--all-targets` and `--no-deps`, so it skips dependency lints) |
| `-- -D warnings` | Treat warnings as errors (strict CI gate; not the local default) |
| `-- -W clippy::pedantic` | Enable the pedantic group (occasional idiom discovery only) |

## Check without running

```sh
cargo check              # full validity analysis, no binary produced
```

## Project layout (Cargo conventions)

- `src/main.rs` (default binary), `src/lib.rs` (default library), `src/bin/` (extra binaries), `tests/` (integration tests), `examples/`, `benches/`.
- `Cargo.toml` (you write it: package metadata + `[dependencies]`) and `Cargo.lock` (Cargo maintains it: pinned versions) live at the package root.
- `rust-toolchain.toml` (optional, package root): pins the toolchain version/components; rustup applies it automatically. Add it when a project needs a specific toolchain instead of the rustup default.
- `target/` holds build artifacts; keep it in `.gitignore`, never commit it.
- Binaries, examples, benches, integration tests use `kebab-case`; modules within them use `snake_case`.

## Positron / VS Code extensions

Install via Open VSX (Positron's gallery). Verified IDs:

- `rust-lang.rust-analyzer`: official LSP (completion, hover types, inlay hints, diagnostics). **Never** install the deprecated `rust-lang.rust` (old RLS).
- `vadimcn.vscode-lldb` (CodeLLDB): debugger on Linux/macOS.
- `tamasfe.even-better-toml`: `Cargo.toml` syntax/schema.
- `fill-labs.dependi`: dependency versions in `Cargo.toml` (the old `serayuzgur.crates` is deprecated).
- `usernamehw.errorlens`: inline diagnostics (optional).

## References

- The Book: https://doc.rust-lang.org/book/
- Clippy: https://doc.rust-lang.org/clippy/
- rustfmt: https://github.com/rust-lang/rustfmt
- Cargo book (project layout): https://doc.rust-lang.org/cargo/guide/project-layout.html
- API Guidelines (naming): https://rust-lang.github.io/api-guidelines/naming.html
- rust-analyzer: https://rust-analyzer.github.io/
- bacon: https://dystroy.org/bacon/
