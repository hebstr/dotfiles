#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s <arm> [reps] [scenario...]\n' "${0##*/}" >&2
  exit 2
}

(($# >= 1)) || usage
arm=$1
shift
reps=5
if (($# >= 1)) && [[ $1 =~ ^[0-9]+$ ]]; then
  reps=$1
  shift
fi
[[ $arm =~ ^[a-z0-9-]+$ ]] || usage
((reps >= 1)) || usage

here=$(cd "$(dirname "$0")" && pwd)
scenarios=("$@")
if ((${#scenarios[@]} == 0)); then
  for p in "$here"/prompts/*.txt; do
    scenarios+=("$(basename "$p" .txt)")
  done
fi
for s in "${scenarios[@]}"; do
  [[ -f $here/prompts/$s.txt ]] || {
    printf 'unknown scenario: %s\n' "$s" >&2
    exit 2
  }
done

root=${INSTRUCTIONS_AB_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/instructions-ab}
out=$root/$arm
model=${INSTRUCTIONS_AB_MODEL:-claude-opus-5-5}
jobs=${INSTRUCTIONS_AB_JOBS:-3}
budget=${INSTRUCTIONS_AB_BUDGET:-2}
mkdir -p "$out"

pdf_cache=$root/.sources
if [[ ! -s $pdf_cache/report.pdf ]]; then
  mkdir -p "$pdf_cache"
  profile=$(mktemp -d)
  trap 'rm -rf "$profile"' EXIT
  libreoffice --headless -env:UserInstallation="file://$profile" \
    --convert-to pdf --outdir "$pdf_cache" "$here/sources/report.txt" >/dev/null
  [[ -s $pdf_cache/report.pdf ]] || {
    printf 'report.pdf was not produced\n' >&2
    exit 1
  }
fi

{
  printf 'arm\t%s\n' "$arm"
  printf 'date\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'model\t%s\n' "$model"
  printf 'claude\t%s\n' "$(claude --version)"
  printf 'dotfiles_head\t%s\n' "$(git -C "$HOME/dotfiles" rev-parse --short HEAD)"
  printf 'dotfiles_dirty_paths\t%s\n' "$(git -C "$HOME/dotfiles" status --porcelain | wc -l)"
  printf 'claude_md_bytes\t%s\n' "$(wc -c <"$HOME/.claude/CLAUDE.md")"
  for f in "$HOME"/.claude/rules/*.md; do
    head -n 1 "$f" | rg -q '^---$' && awk 'NR > 1 && /^---$/ {exit} NR > 1' "$f" | rg -q '^paths:' && continue
    printf 'unscoped_rule\t%s\t%s\n' "$(basename "$f")" "$(wc -c <"$f")"
  done
} >"$out/meta-$(date -u +%Y%m%dT%H%M%SZ).tsv"

one() {
  local scenario=$1 rep=$2
  local dir=$out/$scenario/$rep
  [[ -s $dir/stream.jsonl ]] && return 0
  rm -rf "$dir"
  mkdir -p "$dir/project"
  if [[ -d $here/fixtures/$scenario ]]; then
    cp -a "$here/fixtures/$scenario/." "$dir/project/"
  fi
  [[ $scenario == pdf ]] && cp "$pdf_cache/report.pdf" "$dir/project/"
  local f base target
  while IFS= read -r -d '' f; do
    base=$(basename "$f")
    target=${base%.in}
    target=${target/#dot-/.}
    [[ $target != "$base" ]] && mv "$f" "$(dirname "$f")/$target"
  done < <(find "$dir/project" -depth -name 'dot-*' -print0 -o -name '*.in' -print0)
  cp -a "$dir/project" "$dir/before"
  local start end
  start=$(date +%s)
  (cd "$dir/project" && claude -p "$(cat "$here/prompts/$scenario.txt")" \
    --model "$model" --permission-mode bypassPermissions \
    --output-format stream-json --verbose --no-session-persistence \
    --max-budget-usd "$budget") >"$dir/stream.part" 2>"$dir/stderr.txt" || true
  end=$(date +%s)
  printf '%s\n' "$((end - start))" >"$dir/seconds"
  mv "$dir/stream.part" "$dir/stream.jsonl"
  printf '%s %s %s: done in %ss\n' "$arm" "$scenario" "$rep" "$((end - start))"
}
export -f one
export out here model budget arm pdf_cache

# shellcheck disable=SC2016
for s in "${scenarios[@]}"; do
  for ((r = 1; r <= reps; r++)); do
    printf '%s\0%s\0' "$s" "$r"
  done
done | xargs -0 -n 2 -P "$jobs" bash -c 'one "$1" "$2"' _
