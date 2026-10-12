#!/usr/bin/env bats

SCRIPT="${INJECT_PROJECT_CONTEXT_HOOK:-$BATS_TEST_DIRNAME/../../claude/.claude/hooks/inject-project-context.sh}"

setup() {
  WORK=$(realpath "$(mktemp -d)")
  RUNTIME="$WORK/runtime"
  PROJECT="$WORK/project"
  export WORK RUNTIME PROJECT

  mkdir -p "$RUNTIME" "$PROJECT" "$WORK/.claude/memory"
  printf '# Memory Index\n- a.md: global entry\n' >"$WORK/.claude/memory/MEMORY.md"
}

teardown() {
  rm -rf "$WORK"
}

run_hook() {
  local payload=$1
  # shellcheck disable=SC2016
  run env HOME="$WORK" XDG_RUNTIME_DIR="$RUNTIME" \
    /bin/bash -c 'cd "$3" && printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT" "$PROJECT"
}

@test "clears the session's injection marker on compact" {
  printf 'pdf\n' >"$RUNTIME/claude-code-rules-s1"
  printf 'pdf\n' >"$RUNTIME/claude-code-rules-s1-a1"
  printf 'pdf\n' >"$RUNTIME/claude-code-rules-s2"
  printf 'pdf\n' >"$RUNTIME/claude-code-rules-s2-a1"
  run_hook '{"session_id": "s1", "source": "compact"}'
  [ "$status" -eq 0 ]
  [ ! -e "$RUNTIME/claude-code-rules-s1" ]
  [ ! -e "$RUNTIME/claude-code-rules-s1-a1" ]
  [ -e "$RUNTIME/claude-code-rules-s2" ]
  [ -e "$RUNTIME/claude-code-rules-s2-a1" ]
}

@test "clears the session's injection marker on clear" {
  printf 'pdf\n' >"$RUNTIME/claude-code-rules-s1"
  printf 'pdf\n' >"$RUNTIME/claude-code-rules-s1-a1"
  printf 'pdf\n' >"$RUNTIME/claude-code-rules-s2"
  run_hook '{"session_id": "s1", "source": "clear"}'
  [ "$status" -eq 0 ]
  [ ! -e "$RUNTIME/claude-code-rules-s1" ]
  [ ! -e "$RUNTIME/claude-code-rules-s1-a1" ]
  [ -e "$RUNTIME/claude-code-rules-s2" ]
}

@test "keeps the marker on startup and resume" {
  printf 'pdf\n' >"$RUNTIME/claude-code-rules-s1"
  run_hook '{"session_id": "s1", "source": "startup"}'
  run_hook '{"session_id": "s1", "source": "resume"}'
  [ -e "$RUNTIME/claude-code-rules-s1" ]
}

@test "ignores an unsafe session id" {
  mkdir -p "$RUNTIME/claude-code-rules-sub"
  printf 'pdf\n' >"$RUNTIME/outside"
  run_hook '{"session_id": "sub/../outside", "source": "compact"}'
  [ -e "$RUNTIME/outside" ]
}

@test "points at .claude/PLAN.md on startup and after compaction" {
  mkdir -p "$PROJECT/.claude"
  : >"$PROJECT/.claude/PLAN.md"
  run_hook '{"session_id": "s1", "source": "startup"}'
  [[ $output == *'This project has .claude/PLAN.md: read it'* ]]
  run_hook '{"session_id": "s1", "source": "compact"}'
  [[ $output == *'re-read .claude/PLAN.md'* ]]
}

@test "falls back to a root PLAN.md and flags it as legacy" {
  : >"$PROJECT/PLAN.md"
  run_hook '{"session_id": "s1", "source": "startup"}'
  [[ $output == *'This project has PLAN.md'* ]]
  [[ $output == *'Legacy root-level Claude file(s): PLAN.md.'* ]]
}

@test "lists every root-level Claude file it treats as legacy" {
  : >"$PROJECT/PLAN.md"
  : >"$PROJECT/MEMORY.md"
  : >"$PROJECT/DEFERRED.md"
  run_hook '{"session_id": "s1", "source": "startup"}'
  [[ $output == *'Legacy root-level Claude file(s): PLAN.md MEMORY.md DEFERRED.md.'* ]]
}

@test "says nothing about plans or legacy files in a bare project" {
  run_hook '{"session_id": "s1", "source": "startup"}'
  [[ $output != *PLAN* ]]
  [[ $output != *Legacy* ]]
}

@test "flags a root CLAUDE.md masking .claude/CLAUDE.md" {
  mkdir -p "$PROJECT/.claude"
  : >"$PROJECT/CLAUDE.md"
  : >"$PROJECT/.claude/CLAUDE.md"
  run_hook '{"session_id": "s1", "source": "resume"}'
  [[ $output == *'root copy masks the other'* ]]
}

@test "says nothing about legacy or masking files after a compaction" {
  mkdir -p "$PROJECT/.claude"
  : >"$PROJECT/CLAUDE.md"
  : >"$PROJECT/.claude/CLAUDE.md"
  run_hook '{"session_id": "s1", "source": "compact"}'
  [[ $output != *Legacy* ]]
  [[ $output != *masks* ]]
}

@test "prints the pointer before the project memory index" {
  mkdir -p "$PROJECT/.claude/memory"
  : >"$PROJECT/.claude/PLAN.md"
  printf -- '- b.md: project entry\n' >"$PROJECT/.claude/memory/MEMORY.md"
  run_hook '{"session_id": "s1", "source": "startup"}'
  [[ $output == *'This project has'*'Project memory index'* ]]
}

@test "never prints the global memory index" {
  run_hook '{"session_id": "s1", "source": "startup"}'
  [ "$status" -eq 0 ]
  [[ $output != *'global entry'* ]]
  [[ $output != *'memory index'* ]]
}

@test "prints a project memory index whatever the payload" {
  mkdir -p "$PROJECT/.claude/memory"
  printf -- '- b.md: project entry\n' >"$PROJECT/.claude/memory/MEMORY.md"
  run_hook 'not json'
  [ "$status" -eq 0 ]
  [[ $output == *'Project memory index'*'- b.md: project entry'* ]]
}

@test "skips a project index that resolves to the global store" {
  mkdir -p "$PROJECT/.claude"
  ln -s "$WORK/.claude/memory" "$PROJECT/.claude/memory"
  run_hook '{"session_id": "s1", "source": "startup"}'
  [[ $output != *'memory index'* ]]
  [[ $output != *'global entry'* ]]
}

@test "skips the store itself when the global path links to the project" {
  rm -r "$WORK/.claude/memory"
  mkdir -p "$PROJECT/.claude/memory"
  printf -- '- a.md: global entry\n' >"$PROJECT/.claude/memory/MEMORY.md"
  ln -s "$PROJECT/.claude/memory" "$WORK/.claude/memory"
  run_hook '{"session_id": "s1", "source": "startup"}'
  [[ $output != *'memory index'* ]]
  [[ $output != *'global entry'* ]]
}

# ─── project-type branches ──────────────────────────────────────────────────
# The three blocks are independent ifs keyed on marker files in the working
# directory, so each is pinned on its own and once together. Inside a block the
# arms are exclusive: DESCRIPTION shadows the rv lockfile, and a uv-managed
# pyproject.toml shadows the bare-lockfile fallback.

startup() {
  run_hook '{"session_id": "s1", "source": "startup"}'
}

@test "names the R package and its version from DESCRIPTION" {
  printf 'Package: hebstr\nVersion: 0.3.1\n' >"$PROJECT/DESCRIPTION"
  startup
  [[ $output == *'R package: hebstr v0.3.1'* ]]
}

@test "flags an rv-managed project from either of its two markers" {
  for marker in rv.lock rproject.toml; do
    rm -f "$PROJECT"/rv.lock "$PROJECT"/rproject.toml
    : >"$PROJECT/$marker"
    startup
    [[ $output == *'R project (rv-managed)'* ]] || {
      printf 'not flagged from: %s\n' "$marker" >&2
      return 1
    }
    [[ $output == *"'rv add <pkg>'"* ]]
  done
}

@test "lets DESCRIPTION shadow the rv-managed arm" {
  printf 'Package: hebstr\nVersion: 0.3.1\n' >"$PROJECT/DESCRIPTION"
  : >"$PROJECT/rv.lock"
  startup
  [[ $output == *'R package: hebstr'* ]]
  [[ $output != *'rv-managed'* ]]
}

@test "says nothing about R without either marker" {
  startup
  [[ $output != *'R package'* ]]
  [[ $output != *'rv-managed'* ]]
}

@test "names the Quarto project type and its inline format" {
  printf 'project:\n  type: book\nformat: typst\n' >"$PROJECT/_quarto.yml"
  startup
  [[ $output == *'Quarto project (type: book), format: typst.'* ]]
}

@test "omits the format when _quarto.yml declares it as a block" {
  printf 'project:\n  type: website\nformat:\n  html: default\n' >"$PROJECT/_quarto.yml"
  startup
  [[ $output == *'Quarto project (type: website).'* ]]
}

@test "names a Quarto project carrying neither key" {
  printf 'project:\n  output-dir: _site\n' >"$PROJECT/_quarto.yml"
  startup
  [[ $output == *'Quarto project.'* ]]
}

@test "lists the installed Quarto extensions" {
  : >"$PROJECT/_quarto.yml"
  mkdir -p "$PROJECT/_extensions/hebstr-doc" "$PROJECT/_extensions/quarto-fontawesome"
  startup
  [[ $output == *'Quarto extensions: '*hebstr-doc* ]]
  [[ $output == *quarto-fontawesome* ]]
}

@test "says nothing about extensions when _extensions is empty" {
  : >"$PROJECT/_quarto.yml"
  mkdir -p "$PROJECT/_extensions"
  startup
  [[ $output != *'Quarto extensions'* ]]
}

@test "flags Typst output whatever the case of the declaration" {
  for decl in typst Typst TYPST; do
    printf 'format: %s\n' "$decl" >"$PROJECT/_quarto.yml"
    startup
    [[ $output == *'Typst output format. Use Typst syntax, not LaTeX.'* ]] || {
      printf 'not flagged from: %s\n' "$decl" >&2
      return 1
    }
  done
}

@test "says nothing about Typst for an html format" {
  printf 'format: html\n' >"$PROJECT/_quarto.yml"
  startup
  [[ $output != *Typst* ]]
}

@test "says nothing about Quarto without a _quarto.yml" {
  mkdir -p "$PROJECT/_extensions/hebstr-doc"
  printf 'format: typst\n' >"$PROJECT/_metadata.yml"
  startup
  [[ $output != *Quarto* ]]
  [[ $output != *Typst* ]]
}

@test "names the uv project and its Python floor from pyproject.toml" {
  printf '[project]\nname = "pyapp"\nrequires-python = ">=3.13"\n' >"$PROJECT/pyproject.toml"
  : >"$PROJECT/uv.lock"
  startup
  [[ $output == *'uv project: pyapp (Python >=3.13).'* ]]
}

@test "names a uv project declared by [tool.uv] alone, without a lockfile" {
  printf '[project]\nname = "pyapp"\n[tool.uv]\n' >"$PROJECT/pyproject.toml"
  startup
  [[ $output == *'uv project: pyapp.'* ]]
}

@test "falls back to a bare uv environment for a lockfile without pyproject.toml" {
  : >"$PROJECT/uv.lock"
  startup
  [[ $output == *'uv environment detected.'* ]]
}

@test "says nothing about uv for a pyproject.toml that uv does not manage" {
  printf '[project]\nname = "pyapp"\n[tool.ruff]\nline-length = 88\n' >"$PROJECT/pyproject.toml"
  startup
  [[ $output != *uv* ]]
}

@test "prints the R, Quarto and uv lines together" {
  printf 'Package: hebstr\nVersion: 0.3.1\n' >"$PROJECT/DESCRIPTION"
  printf 'project:\n  type: book\nformat: typst\n' >"$PROJECT/_quarto.yml"
  printf '[project]\nname = "pyapp"\n' >"$PROJECT/pyproject.toml"
  : >"$PROJECT/uv.lock"
  startup
  [[ $output == *'R package: hebstr'*'Quarto project'*'uv project: pyapp'* ]]
}
