#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2016
# Tests for bin/.local/bin/transcribe and the pure path of transcribe-payload.py

bats_require_minimum_version 1.5.0

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/transcribe"
PAYLOAD="${BATS_TEST_DIRNAME}/../../bin/.local/bin/transcribe-payload.py"

_stub_command() {
  local name="$1" body="${2:-exit 0}"
  cat >"${STUBS}/${name}" <<EOF
#!/usr/bin/env bash
${body}
EOF
  chmod +x "${STUBS}/${name}"
}

_install_ssh_stub() {
  _stub_command ssh '
printf "%s\n" "$*" >>"${SSH_LOG}"
if [ -n "${SSH_UNREACHABLE:-}" ]; then
  [ -z "${SSH_ERROR:-}" ] || printf "%s\n" "${SSH_ERROR}" >&2
  exit 255
fi
n=$(($(cat "${STATE}/ssh_calls" 2>/dev/null || printf 0) + 1))
printf "%s\n" "$n" >"${STATE}/ssh_calls"
[ "$n" != "${SSH_DROP_AT:-}" ] || exit 255
case "$*" in
*"mktemp -d"*)
  mkdir -p "${STATE}/scratch"
  printf "%s\r\n" "${STATE}/scratch"
  exit 0
  ;;
*libcublas*)
  [ -z "${NO_CUBLAS:-}" ] || exit 1
  exit 0
  ;;
*huggingface/token*)
  [ -z "${NO_TOKEN:-}" ] || exit 1
  exit 0
  ;;
*"rm -rf"*)
  # the stub removes only the scratch it was actually sent, so that a driver
  # naming another path leaves the directory standing
  [ -z "${RM_UNREACHABLE:-}" ] || exit 255
  sent=${*: -1}
  [ "${sent#rm -rf }" != "${STATE}/scratch" ] || rm -rf "${STATE}/scratch"
  exit 0
  ;;
*"uv run"*)
  if [ -n "${LOCK_STALE:-}" ]; then
    printf "error: The lockfile at uv.lock needs to be updated, but --locked was provided\n" >&2
    exit 1
  fi
  [ -z "${STAGE_FAILS:-}" ] || exit 1
  mkdir -p "${STATE}/scratch"
  audio=$(printf "%s\n" "$*" | sed -n "s/.*--audio \([^ ]*\).*/\1/p")
  stem=${audio##*/}
  stem=${stem%%.*}
  # the payload refuses an existing target unless --force, and on the remote it
  # looks inside the scratch the stage runs in
  case "$*" in
  *" diarize "*)
    # the real payload rewrites the transcript with a speaker label, which is
    # what tells the output of this stage from the output of the asr stage
    [ -z "${DIARIZE_FAILS:-}" ] || exit 1
    label="S1: "
    ;;
  *" asr "*)
    case "$*" in
    *--force*) ;;
    *)
      if [ -e "${STATE}/scratch/${stem}.json" ]; then
        printf "exists, pass --force to overwrite: %s\n" "${STATE}/scratch/${stem}.json" >&2
        exit 1
      fi
      ;;
    esac
    ;;
  esac
  printf "{\"segments\": []}\n" >"${STATE}/scratch/${stem}.json"
  printf "[00:00.0] %sstub transcript\n" "${label:-}" >"${STATE}/scratch/${stem}.txt"
  exit 0
  ;;
esac
exit 0'
}

_install_scp_stub() {
  _stub_command scp '
printf "%s\n" "$*" >>"${SCP_LOG}"
if [ -n "${SCP_FAILS:-}" ]; then
  printf "scp: realpath %s: No such file or directory\n" "$1" >&2
  exit 1
fi
paths=()
while [ $# -gt 0 ]; do
  case "$1" in
  -o)
    shift 2
    ;;
  -q | -r | -p | --)
    shift
    ;;
  *)
    paths+=("$1")
    shift
    ;;
  esac
done
last=$((${#paths[@]} - 1))
dest=${paths[$last]}
dest=${dest#*:}
i=0
while [ "$i" -lt "$last" ]; do
  src=${paths[$i]}
  cp "${src#*:}" "$dest" || exit 1
  i=$((i + 1))
done
exit 0'
}

_install_uv_stub() {
  _stub_command uv '
printf "%s\n" "$*" >>"${UV_LOG}"
if [ -n "${LOCK_STALE:-}" ]; then
  printf "error: The lockfile at uv.lock needs to be updated, but --locked was provided\n" >&2
  exit 1
fi
[ -z "${STAGE_FAILS:-}" ] || exit 1
audio=$(printf "%s\n" "$*" | sed -n "s/.*--audio \([^ ]*\).*/\1/p")
outdir=$(printf "%s\n" "$*" | sed -n "s/.*--out-dir \([^ ]*\).*/\1/p")
stem=${audio##*/}
stem=${stem%%.*}
dir=${outdir:-$(dirname "$audio")}
printf "{\"segments\": []}\n" >"${dir}/${stem}.json"
printf "[00:00.0] stub transcript\n" >"${dir}/${stem}.txt"
exit 0'
}

setup() {
  unset TRANSCRIBE_REMOTE
  STUBS="$(mktemp -d)"
  STATE="$(mktemp -d)"
  SSH_LOG="$(mktemp -u)"
  SCP_LOG="$(mktemp -u)"
  UV_LOG="$(mktemp -u)"
  export STUBS STATE SSH_LOG SCP_LOG UV_LOG
  for cmd in basename cat cp dirname mkdir mktemp printf readlink realpath rm sed touch tr; do
    ln -s "$(type -P "$cmd")" "${STUBS}/${cmd}"
  done
  ln -s "$BASH" "${STUBS}/bash"
  ln -s "$(type -P python3.14)" "${STUBS}/python3.14"
  _install_ssh_stub
  _install_scp_stub
  _install_uv_stub
  AUDIO="${STATE}/rec.3gpp.3ga"
  touch "$AUDIO"
  export AUDIO
}

teardown() {
  rm -rf "$STUBS" "$STATE" "$SSH_LOG" "$SCP_LOG" "$UV_LOG"
}

_run() {
  run env PATH="$STUBS" HOME="$STATE" STATE="$STATE" SSH_LOG="$SSH_LOG" SCP_LOG="$SCP_LOG" UV_LOG="$UV_LOG" \
    SSH_UNREACHABLE="${SSH_UNREACHABLE:-}" NO_CUBLAS="${NO_CUBLAS:-}" NO_TOKEN="${NO_TOKEN:-}" \
    RM_UNREACHABLE="${RM_UNREACHABLE:-}" LOCK_STALE="${LOCK_STALE:-}" \
    SSH_DROP_AT="${SSH_DROP_AT:-}" SSH_ERROR="${SSH_ERROR:-}" \
    STAGE_FAILS="${STAGE_FAILS:-}" SCP_FAILS="${SCP_FAILS:-}" \
    DIARIZE_FAILS="${DIARIZE_FAILS:-}" \
    TRANSCRIBE_REMOTE="${TRANSCRIBE_REMOTE:-}" HF_TOKEN="${HF_TOKEN:-}" \
    "$BASH" "$SCRIPT" "$@"
}

_payload() {
  run env PATH="$STUBS" python3.14 "$PAYLOAD" "$@"
}

PURE='
import importlib.util, json, sys

spec = importlib.util.spec_from_file_location("payload", sys.argv[1])
payload = importlib.util.module_from_spec(spec)
spec.loader.exec_module(payload)

record = json.loads(sys.argv[2])
renumbered, _ = payload.label_segments(record["segments"], record.get("turns", []))
print(payload.render(record["segments"], renumbered), end="")
'

_render() {
  run env PATH="$STUBS" python3.14 -c "$PURE" "$PAYLOAD" "$1"
}

LABELS='
import importlib.util, json, sys

spec = importlib.util.spec_from_file_location("payload", sys.argv[1])
payload = importlib.util.module_from_spec(spec)
spec.loader.exec_module(payload)

record = json.loads(sys.argv[2])
_, labels = payload.label_segments(record["segments"], record.get("turns", []))
print(json.dumps(labels, sort_keys=True), end="")
'

_labels() {
  run env PATH="$STUBS" python3.14 -c "$LABELS" "$PAYLOAD" "$1"
}

# ─── argument handling ──────────────────────────────────────────────────────

@test "--help prints usage and exits 0" {
  _run --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: transcribe"* ]]
  [[ "$output" == *"--speakers"* ]]
  [[ "$output" == *"--local"* ]]
  [[ "$output" == *"TRANSCRIBE_REMOTE"* ]]
}

@test "an unknown argument exits 1 and names it" {
  _run --frobnicate "$AUDIO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown argument: --frobnicate"* ]]
}

@test "an option given without its value is named rather than left to set -u" {
  _run --speakers
  [ "$status" -eq 1 ]
  [[ "$output" == *"--speakers needs a count"* ]]
  _run --model
  [ "$status" -eq 1 ]
  [[ "$output" == *"--model needs an id"* ]]
  _run --language
  [ "$status" -eq 1 ]
  [[ "$output" == *"--language needs a code"* ]]
  _run --out-dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"--out-dir needs a directory"* ]]
}

@test "no audio file exits 1 and nothing is sent" {
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"no audio file"* ]]
  [ ! -e "$SSH_LOG" ]
}

@test "an audio file that does not exist exits 1 before any ssh" {
  _run "${STATE}/absent.m4a"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a file"* ]]
  [ ! -e "$SSH_LOG" ]
}

# ─── the six refusals ───────────────────────────────────────────────────────

@test "refusal: --speakers below 1 is refused before any ssh" {
  _run --speakers 0 "$AUDIO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--speakers must be 1 or more"* ]]
  [ ! -e "$SSH_LOG" ]
}

@test "refusal: a non-numeric --speakers is refused" {
  _run --speakers three "$AUDIO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--speakers must be 1 or more"* ]]
}

@test "refusal: an unreachable remote refuses rather than falling back to this host" {
  SSH_UNREACHABLE=1 _run "$AUDIO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot reach"* ]]
  [ ! -e "$UV_LOG" ]
  [ ! -e "$SCP_LOG" ]
}

@test "refusal: a missing libcublas.so.12 is named and nothing is staged" {
  NO_CUBLAS=1 _run "$AUDIO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"libcublas.so.12"* ]]
  [ ! -e "$SCP_LOG" ]
}

@test "a host lost at the library check is called unreachable, not short of a library" {
  SSH_DROP_AT=2 _run "$AUDIO"
  [ "$status" -eq 1 ]
  [ "$(cat "${STATE}/ssh_calls")" -eq 2 ]
  grep -q "libcublas" "$SSH_LOG"
  [[ "$output" == *"cannot reach"* ]]
  [[ "$output" != *"libcublas"* ]]
}

@test "a host lost at the token check is called unreachable, not short of a token" {
  SSH_DROP_AT=3 _run --speakers 2 "$AUDIO"
  [ "$status" -eq 1 ]
  [ "$(cat "${STATE}/ssh_calls")" -eq 3 ]
  grep -q "huggingface/token" "$SSH_LOG"
  [[ "$output" == *"cannot reach"* ]]
  [[ "$output" != *"Hugging Face token"* ]]
}

@test "refusal: no Hugging Face token on the chosen host when diarization is asked" {
  NO_TOKEN=1 _run --speakers 2 "$AUDIO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Hugging Face token"* ]]
  [ ! -e "$SCP_LOG" ]
}

@test "an absent token is not checked when no diarization is asked" {
  NO_TOKEN=1 _run "$AUDIO"
  [ "$status" -eq 0 ]
  run ! grep -q "huggingface/token" "$SSH_LOG"
}

@test "refusal: a stale lock is surfaced rather than swallowed" {
  LOCK_STALE=1 _run "$AUDIO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--locked"* ]]
}

@test "refusal: an existing transcript without --force is refused before any ssh" {
  touch "${STATE}/rec.txt"
  _run "$AUDIO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--force"* ]]
  [ ! -e "$SSH_LOG" ]
}

@test "--force overwrites an existing transcript" {
  touch "${STATE}/rec.txt" "${STATE}/rec.json"
  _run --force "$AUDIO"
  [ "$status" -eq 0 ]
  [[ "$(cat "${STATE}/rec.txt")" == *"stub transcript"* ]]
}

@test "--force reaches the asr stage on the local path" {
  touch "${STATE}/rec.txt"
  _run --local --force "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q -- "--force" "$UV_LOG"
}

@test "refusal: two recordings of one run writing the same outputs are refused" {
  touch "${STATE}/rec.m4a"
  _run "$AUDIO" "${STATE}/rec.m4a"
  [ "$status" -eq 1 ]
  [[ "$output" == *"write the same outputs"* ]]
  [ ! -e "$SSH_LOG" ]
  [ ! -e "$SCP_LOG" ]
}

@test "refusal: --out-dir collapsing homonyms from different directories is refused" {
  mkdir -p "${STATE}/a" "${STATE}/b"
  touch "${STATE}/a/rec.m4a" "${STATE}/b/rec.m4a"
  _run --out-dir "${STATE}/out" "${STATE}/a/rec.m4a" "${STATE}/b/rec.m4a"
  [ "$status" -eq 1 ]
  [[ "$output" == *"write the same outputs"* ]]
  [ ! -e "$SSH_LOG" ]
  [ ! -e "$SCP_LOG" ]
}

@test "refusal: two recordings colliding through a dot segment are refused" {
  mkdir -p "${STATE}/a"
  touch "${STATE}/a/rec.3gpp" "${STATE}/a/rec.3ga"
  _run "${STATE}/a/rec.3gpp" "${STATE}/a/./rec.3ga"
  [ "$status" -eq 1 ]
  [[ "$output" == *"write the same outputs"* ]]
  [ ! -e "$SSH_LOG" ]
}

@test "--force does not license clobbering an output the same run just wrote" {
  touch "${STATE}/rec.m4a"
  _run --force "$AUDIO" "${STATE}/rec.m4a"
  [ "$status" -eq 1 ]
  [[ "$output" == *"write the same outputs"* ]]
  [ ! -e "$SSH_LOG" ]
}

# ─── host choice ────────────────────────────────────────────────────────────

@test "the remote is the default host and the payload is reached inside the synced tree" {
  _run "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q -F -- " ju-TP2 " "$SSH_LOG"
  grep -q "dotfiles/bin/.local/bin/transcribe-payload.py" "$SSH_LOG"
  grep -q -- "uv run --locked --script" "$SSH_LOG"
  [ "$(grep -c -F -- "-o BatchMode=yes" "$SSH_LOG")" -eq "$(wc -l <"$SSH_LOG")" ]
  [ "$(grep -c -F -- "-o BatchMode=yes" "$SCP_LOG")" -eq "$(wc -l <"$SCP_LOG")" ]
  [ ! -e "$UV_LOG" ]
}

@test "the remote stage runs inside the scratch on the staged basename" {
  _run "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q -F -- "cd ${STATE}/scratch " "$SSH_LOG"
  grep -q -F -- "--audio rec.3gpp.3ga " "$SSH_LOG"
  run ! grep -q -F -- "--audio ${STATE}/" "$SSH_LOG"
}

@test "the remote pass points LD_LIBRARY_PATH at the llama.cpp tree" {
  _run "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q -F -- 'LD_LIBRARY_PATH=$HOME/.local/opt/llama.cpp' "$SSH_LOG"
}

@test "TRANSCRIBE_REMOTE names another host" {
  TRANSCRIBE_REMOTE=other-host _run "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q "other-host" "$SSH_LOG"
  run ! grep -q "ju-TP2" "$SSH_LOG"
}

@test "--local runs the payload here and never opens an ssh connection" {
  _run --local "$AUDIO"
  [ "$status" -eq 0 ]
  [ ! -e "$SSH_LOG" ]
  [ ! -e "$SCP_LOG" ]
  grep -q -- "run --locked --script" "$UV_LOG"
}

@test "--local checks the token on this host when diarization is asked" {
  _run --local --speakers 2 "$AUDIO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Hugging Face token"* ]]
}

@test "HF_TOKEN in the environment stands in for the token file" {
  HF_TOKEN=hf_stub _run --local --speakers 2 "$AUDIO"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Hugging Face token"* ]]
}

@test "the token file on this host stands in for HF_TOKEN" {
  mkdir -p "${STATE}/.cache/huggingface"
  touch "${STATE}/.cache/huggingface/token"
  _run --local --speakers 2 "$AUDIO"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Hugging Face token"* ]]
}

# ─── per-host defaults ──────────────────────────────────────────────────────

@test "the remote decodes on the GPU at float16 over 24 threads" {
  _run "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q -E -- '--device cuda( |$)' "$SSH_LOG"
  grep -q -E -- '--compute-type float16( |$)' "$SSH_LOG"
  grep -q -E -- '--threads 24( |$)' "$SSH_LOG"
}

@test "--local decodes on the CPU at int8 over 12 threads" {
  _run --local "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q -E -- '--device cpu( |$)' "$UV_LOG"
  grep -q -E -- '--compute-type int8( |$)' "$UV_LOG"
  grep -q -E -- '--threads 12( |$)' "$UV_LOG"
}

@test "--model and --language reach the payload" {
  _run --model some/model --language en "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q -E -- '--model some/model( |$)' "$SSH_LOG"
  grep -q -E -- '--language en( |$)' "$SSH_LOG"
}

# ─── diarization wiring ─────────────────────────────────────────────────────

@test "no diarization flag runs the asr stage alone" {
  _run "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q " asr " "$SSH_LOG"
  run ! grep -q " diarize " "$SSH_LOG"
}

@test "--speakers imposes the count on the diarize stage" {
  _run --speakers 3 "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q " diarize " "$SSH_LOG"
  grep -q -E -- '--speakers 3( |$)' "$SSH_LOG"
}

@test "--diarize runs the stage without imposing a count" {
  _run --diarize "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q " diarize " "$SSH_LOG"
  run ! grep -q -- "--speakers" "$SSH_LOG"
}

@test "the diarize stage gets the 24 CPU threads of the remote" {
  _run --speakers 2 "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q -E -- 'diarize .*--threads 24( |$)' "$SSH_LOG"
}

@test "the labelled transcript of the diarize stage is brought back here" {
  _run --speakers 2 "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q -F -- "S1: stub transcript" "${STATE}/rec.txt"
}

# ─── outputs and teardown ───────────────────────────────────────────────────

@test "the transcript and its json land beside the source" {
  _run "$AUDIO"
  [ "$status" -eq 0 ]
  [ -f "${STATE}/rec.txt" ]
  [ -f "${STATE}/rec.json" ]
  [[ "$output" == *"rec.txt"* ]]
}

@test "--out-dir takes the outputs instead of the source directory" {
  _run --out-dir "${STATE}/out" "$AUDIO"
  [ "$status" -eq 0 ]
  [ -f "${STATE}/out/rec.txt" ]
  [ ! -e "${STATE}/rec.txt" ]
}

@test "--local --out-dir reaches the payload and lands the outputs there" {
  _run --local --out-dir "${STATE}/out" "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q -F -- "--out-dir ${STATE}/out" "$UV_LOG"
  [ -f "${STATE}/out/rec.txt" ]
  [ ! -e "${STATE}/rec.txt" ]
}

@test "the remote scratch is removed on exit" {
  _run "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q -- "rm -rf" "$SSH_LOG"
  [ ! -e "${STATE}/scratch" ]
}

@test "a scratch the driver could not remove is reported rather than claimed gone" {
  RM_UNREACHABLE=1 _run "$AUDIO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"could not remove"* ]]
  [[ "$output" == *"scratch"* ]]
}

@test "a failing stage still tears the scratch down" {
  STAGE_FAILS=1 _run "$AUDIO"
  [ "$status" -ne 0 ]
  grep -q -- "rm -rf" "$SSH_LOG"
  [ ! -e "${STATE}/scratch" ]
}

@test "several recordings are staged and brought back one by one" {
  touch "${STATE}/second.m4a"
  _run "$AUDIO" "${STATE}/second.m4a"
  [ "$status" -eq 0 ]
  [ -f "${STATE}/rec.txt" ]
  [ -f "${STATE}/second.txt" ]
}

@test "homonyms from different directories are both decoded on the remote" {
  mkdir -p "${STATE}/a" "${STATE}/b"
  touch "${STATE}/a/rec.m4a" "${STATE}/b/rec.m4a"
  _run "${STATE}/a/rec.m4a" "${STATE}/b/rec.m4a"
  [ "$status" -eq 0 ]
  [ -f "${STATE}/a/rec.txt" ]
  [ -f "${STATE}/b/rec.txt" ]
}

@test "a failing diarization keeps the transcript already decoded" {
  DIARIZE_FAILS=1 _run --speakers 2 "$AUDIO"
  [ "$status" -ne 0 ]
  [ -f "${STATE}/rec.txt" ]
  [ -f "${STATE}/rec.json" ]
  grep -q -- "rm -rf" "$SSH_LOG"
}

@test "a failing scp is surfaced rather than swallowed" {
  SCP_FAILS=1 _run "$AUDIO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No such file or directory"* ]]
  [ ! -f "${STATE}/rec.txt" ]
  grep -q -- "rm -rf" "$SSH_LOG"
}

@test "the unreachable refusal carries ssh's own last line, not its banner" {
  SSH_UNREACHABLE=1 \
    SSH_ERROR=$'@@@@ WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED! @@@@\nHost key verification failed.' \
    _run "$AUDIO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot reach"* ]]
  [[ "$output" == *"Host key verification failed."* ]]
  [[ "$output" != *"REMOTE HOST IDENTIFICATION HAS CHANGED"* ]]
}

@test "an unreachable remote on a diarization run is not answered with --local" {
  SSH_UNREACHABLE=1 HF_TOKEN='' _run --speakers 2 "$AUDIO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot reach"* ]]
  [[ "$output" == *"cannot diarize"* ]]
  [[ "$output" != *"pass --local to decode here instead"* ]]
}

@test "an unreachable remote on a diarization run offers labelling when the token is here" {
  SSH_UNREACHABLE=1 HF_TOKEN=hf_stub _run --speakers 2 "$AUDIO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot reach"* ]]
  [[ "$output" == *"pass --local to decode and label here"* ]]
  [[ "$output" != *"cannot diarize"* ]]
}

@test "a recording named relatively reaches scp as an absolute path" {
  cd "$STATE" || return 1
  _run rec.3gpp.3ga
  [ "$status" -eq 0 ]
  grep -q -F -- "${STATE}/rec.3gpp.3ga" "$SCP_LOG"
}

# ─── the payload's pure path, under the bare interpreter ────────────────────

@test "the payload renders a transcript without a speaker label" {
  _render '{"segments": [{"start": 0.0, "end": 1.0, "text": "bonjour"}]}'
  [ "$status" -eq 0 ]
  [ "$output" = "[00:00.0] bonjour" ]
}

@test "the payload stamps minutes and tenths of a second" {
  _render '{"segments": [{"start": 125.46, "end": 126.0, "text": "x"}]}'
  [ "$status" -eq 0 ]
  [ "$output" = "[02:05.5] x" ]
}

@test "the payload carries the minute when the seconds round up to 60" {
  _render '{"segments": [{"start": 59.96, "end": 61.0, "text": "un"},
                         {"start": 59.94, "end": 60.0, "text": "deux"}]}'
  [ "$status" -eq 0 ]
  [ "$output" = "[01:00.0] un"$'\n'"[00:59.9] deux" ]
}

@test "the payload renumbers the raw labels by order of first appearance" {
  _render '{"segments": [{"start": 0.0, "end": 2.0, "text": "un"},
                         {"start": 3.0, "end": 4.0, "text": "deux"},
                         {"start": 5.0, "end": 6.0, "text": "trois"}],
            "turns": [{"start": 0.0, "end": 2.0, "speaker": "SPEAKER_01"},
                      {"start": 3.0, "end": 4.0, "speaker": "SPEAKER_00"},
                      {"start": 5.0, "end": 6.0, "speaker": "SPEAKER_01"}]}'
  [ "$status" -eq 0 ]
  [ "$output" = "[00:00.0] S1: un"$'\n'"[00:03.0] S2: deux"$'\n'"[00:05.0] S1: trois" ]
}

@test "the payload gives a segment the speaker holding most of it" {
  _render '{"segments": [{"start": 0.0, "end": 10.0, "text": "un"}],
            "turns": [{"start": 0.0, "end": 2.0, "speaker": "SPEAKER_00"},
                      {"start": 2.0, "end": 10.0, "speaker": "SPEAKER_01"}]}'
  [ "$status" -eq 0 ]
  [ "$output" = "[00:00.0] S1: un" ]
}

@test "the payload labels a turn speaker that wins no segment" {
  _labels '{"segments": [{"start": 0.0, "end": 10.0, "text": "un"}],
            "turns": [{"start": 0.0, "end": 2.0, "speaker": "SPEAKER_00"},
                      {"start": 2.0, "end": 10.0, "speaker": "SPEAKER_01"}]}'
  [ "$status" -eq 0 ]
  [ "$output" = '{"SPEAKER_00": "S2", "SPEAKER_01": "S1"}' ]
}

@test "the payload leaves a segment overlapping no turn unlabelled" {
  _render '{"segments": [{"start": 0.0, "end": 1.0, "text": "un"},
                         {"start": 50.0, "end": 51.0, "text": "deux"}],
            "turns": [{"start": 0.0, "end": 1.0, "speaker": "SPEAKER_00"}]}'
  [ "$status" -eq 0 ]
  [ "$output" = "[00:00.0] S1: un"$'\n'"[00:50.0] deux" ]
}

@test "the payload names the outputs after the audio stripped of its suffixes" {
  _payload asr --print-target --audio /tmp/2026-03-23_meeting.3gpp.3ga
  [ "$status" -eq 0 ]
  [ "$output" = "/tmp/2026-03-23_meeting" ]
}

@test "the payload strips one audio suffix as well as two" {
  _payload asr --print-target --audio /tmp/rec.m4a
  [ "$status" -eq 0 ]
  [ "$output" = "/tmp/rec" ]
}

@test "the payload strips an audio suffix spelled in upper case" {
  _payload asr --print-target --audio /tmp/rec.WAV
  [ "$status" -eq 0 ]
  [ "$output" = "/tmp/rec" ]
}

@test "the payload keeps a suffix that names no audio format" {
  _payload asr --print-target --audio /tmp/notes.2026.wav
  [ "$status" -eq 0 ]
  [ "$output" = "/tmp/notes.2026" ]
}

@test "--out-dir moves the payload's target without renaming it" {
  _payload asr --print-target --audio /tmp/rec.3gpp.3ga --out-dir /elsewhere
  [ "$status" -eq 0 ]
  [ "$output" = "/elsewhere/rec" ]
}

@test "the payload refuses a speaker count below 1" {
  _payload diarize --audio "$AUDIO" --speakers 0
  [ "$status" -eq 1 ]
  [[ "$output" == *"--speakers must be 1 or more"* ]]
}

@test "the payload refuses an existing target without --force" {
  printf '{}\n' >"${STATE}/rec.json"
  _payload asr --audio "$AUDIO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"exists, pass --force to overwrite"* ]]
}

@test "the payload refuses an audio file that does not exist" {
  _payload asr --audio "${STATE}/absent.m4a"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a file"* ]]
}
