#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

SCRIPT="${CLEAN_COMMENT_HASH:-$BATS_TEST_DIRNAME/../../git/.config/git/clean-comment-hash}"

HASH_A=17bd101638c0acd98b867f9c8fd2de539e81f8eca3050d226ba30002d5deea30
HASH_B=b89824f070ef200dc1bbc5d353a0efa1b41491a726bbd0d3bf48680499fc9d73
ZEROS=0000000000000000000000000000000000000000000000000000000000000000

_entry() {
  printf '{"id":"c%s","range":{"start":{"line":3,"character":0},"end":{"line":3,"character":19}},"selectedText":"crit\303\250re d\342\200\231inclusion","contextBefore":"avant","contextAfter":"apr\303\250s","trackedChanges":[],"documentHash":"%s"}' "$1" "$2"
}

_store() {
  local i=0 sep='' hash
  printf '{"version":1,"comments":['
  for hash in "$@"; do
    i=$((i + 1))
    printf '%s' "$sep"
    _entry "$i" "$hash"
    sep=','
  done
  printf ']}\n'
}

@test "the gitconfig driver points at this script inside the git package" {
  run -0 git config -f "$BATS_TEST_DIRNAME/../../git/.gitconfig" --get filter.comment-hash.clean
  # shellcheck disable=SC2088
  [ "$output" = '~/.config/git/clean-comment-hash' ]
  [ -x "$BATS_TEST_DIRNAME/../../git/.config/git/clean-comment-hash" ]
}

@test "a document hash is replaced by sixty-four zeros" {
  _store "$HASH_A" >"$BATS_TEST_TMPDIR/in.json"
  run -0 --separate-stderr "$SCRIPT" <"$BATS_TEST_TMPDIR/in.json"
  [ -z "$stderr" ]
  [ "$output" = "$(_store "$ZEROS")" ]
}

@test "every entry is normalized and differing hashes collapse to the same value" {
  _store "$HASH_A" "$HASH_B" "$HASH_A" >"$BATS_TEST_TMPDIR/in.json"
  run -0 --separate-stderr "$SCRIPT" <"$BATS_TEST_TMPDIR/in.json"
  [ -z "$stderr" ]
  [ "$output" = "$(_store "$ZEROS" "$ZEROS" "$ZEROS")" ]
}

@test "a second pass changes nothing" {
  _store "$HASH_A" "$HASH_B" >"$BATS_TEST_TMPDIR/in.json"
  "$SCRIPT" <"$BATS_TEST_TMPDIR/in.json" >"$BATS_TEST_TMPDIR/once.json"
  grep -q "\"documentHash\":\"$ZEROS\"" "$BATS_TEST_TMPDIR/once.json"
  "$SCRIPT" <"$BATS_TEST_TMPDIR/once.json" >"$BATS_TEST_TMPDIR/twice.json"
  cmp "$BATS_TEST_TMPDIR/once.json" "$BATS_TEST_TMPDIR/twice.json"
}

@test "nothing but the document hash changes" {
  _store "$HASH_A" "$HASH_B" >"$BATS_TEST_TMPDIR/in.json"
  "$SCRIPT" <"$BATS_TEST_TMPDIR/in.json" >"$BATS_TEST_TMPDIR/out.json"
  run -0 jq -e '.comments[0] | has("range") and has("selectedText") and has("contextBefore") and has("contextAfter") and has("trackedChanges")' "$BATS_TEST_TMPDIR/out.json"
  jq -S 'del(.comments[].documentHash)' "$BATS_TEST_TMPDIR/in.json" >"$BATS_TEST_TMPDIR/in.stripped"
  jq -S 'del(.comments[].documentHash)' "$BATS_TEST_TMPDIR/out.json" >"$BATS_TEST_TMPDIR/out.stripped"
  cmp "$BATS_TEST_TMPDIR/in.stripped" "$BATS_TEST_TMPDIR/out.stripped"
}

@test "the normalized store is still valid JSON" {
  _store "$HASH_A" "$HASH_B" >"$BATS_TEST_TMPDIR/in.json"
  "$SCRIPT" <"$BATS_TEST_TMPDIR/in.json" >"$BATS_TEST_TMPDIR/out.json"
  run -0 jq -e . "$BATS_TEST_TMPDIR/out.json"
}

@test "a value that is not sixty-four lowercase hex is left alone" {
  _store \
    17BD101638C0ACD98B867F9C8FD2DE539E81F8ECA3050D226BA30002D5DEEA30 \
    17bd101638c0acd98b867f9c8fd2de539e81f8eca3050d226ba30002d5deea3 \
    17bd101638c0acd98b867f9c8fd2de539e81f8eca3050d226ba30002d5deea30a \
    "sha256:$HASH_A" >"$BATS_TEST_TMPDIR/in.json"
  "$SCRIPT" <"$BATS_TEST_TMPDIR/in.json" >"$BATS_TEST_TMPDIR/out.json" 2>"$BATS_TEST_TMPDIR/err"
  cmp "$BATS_TEST_TMPDIR/in.json" "$BATS_TEST_TMPDIR/out.json"
  [ ! -s "$BATS_TEST_TMPDIR/err" ]
}

@test "a json without the key passes through byte for byte" {
  printf '{"version":1,"comments":[{"id":"c1","selectedText":"crit\303\250re accentu\303\251","hash":"%s"}]}\r\n' "$HASH_A" >"$BATS_TEST_TMPDIR/in.json"
  "$SCRIPT" <"$BATS_TEST_TMPDIR/in.json" >"$BATS_TEST_TMPDIR/out.json" 2>"$BATS_TEST_TMPDIR/err"
  cmp "$BATS_TEST_TMPDIR/in.json" "$BATS_TEST_TMPDIR/out.json"
  [ ! -s "$BATS_TEST_TMPDIR/err" ]
}

@test "empty input yields empty output and no warning" {
  run -0 --separate-stderr "$SCRIPT" </dev/null
  [ -z "$output" ]
  [ -z "$stderr" ]
}
