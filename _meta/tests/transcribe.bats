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
[ -z "${SSH_UNREACHABLE:-}" ] || exit 255
n=$(($(cat "${STATE}/ssh_calls" 2>/dev/null || printf 0) + 1))
printf "%s\n" "$n" >"${STATE}/ssh_calls"
[ "$n" != "${SSH_DROP_AT:-}" ] || exit 255
case "$*" in
*"mktemp -d"*)
  mkdir -p "${STATE}/scratch"
  printf "%s\n" "${STATE}/scratch"
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
  [ -z "${RM_UNREACHABLE:-}" ] || exit 255
  rm -rf "${STATE}/scratch"
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
  printf "{\"segments\": []}\n" >"${STATE}/scratch/${stem}.json"
  printf "[00:00.0] stub transcript\n" >"${STATE}/scratch/${stem}.txt"
  exit 0
  ;;
esac
exit 0'
}

_install_scp_stub() {
  _stub_command scp '
printf "%s\n" "$*" >>"${SCP_LOG}"
[ -z "${SCP_FAILS:-}" ] || exit 1
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
  for cmd in basename cat cp dirname mkdir mktemp printf readlink rm sed touch tr; do
    [ -e "/usr/bin/${cmd}" ] && ln -s "/usr/bin/${cmd}" "${STUBS}/${cmd}"
  done
  ln -s "$BASH" "${STUBS}/bash"
  ln -s "$(command -v python3.14)" "${STUBS}/python3.14"
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
  run env PATH="$STUBS" STATE="$STATE" SSH_LOG="$SSH_LOG" SCP_LOG="$SCP_LOG" UV_LOG="$UV_LOG" \
    SSH_UNREACHABLE="${SSH_UNREACHABLE:-}" NO_CUBLAS="${NO_CUBLAS:-}" NO_TOKEN="${NO_TOKEN:-}" \
    RM_UNREACHABLE="${RM_UNREACHABLE:-}" LOCK_STALE="${LOCK_STALE:-}" \
    SSH_DROP_AT="${SSH_DROP_AT:-}" \
    STAGE_FAILS="${STAGE_FAILS:-}" SCP_FAILS="${SCP_FAILS:-}" \
    TRANSCRIBE_REMOTE="${TRANSCRIBE_REMOTE:-}" HF_TOKEN= \
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
turns = record.get("turns", [])
assigned = payload.assign_speakers(record["segments"], turns)
labels = payload.renumber(assigned, turns)
renumbered = [labels[s] if s is not None else None for s in assigned]
print(payload.render(record["segments"], renumbered), end="")
'

_render() {
  run env PATH="$STUBS" python3.14 -c "$PURE" "$PAYLOAD" "$1"
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

# ─── host choice ────────────────────────────────────────────────────────────

@test "the remote is the default host and the payload is reached inside the synced tree" {
  _run "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q "ju-TP2" "$SSH_LOG"
  grep -q "dotfiles/bin/.local/bin/transcribe-payload.py" "$SSH_LOG"
  grep -q -- "uv run --locked --script" "$SSH_LOG"
  [ ! -e "$UV_LOG" ]
}

@test "the remote pass points LD_LIBRARY_PATH at the llama.cpp tree" {
  _run "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q "LD_LIBRARY_PATH=" "$SSH_LOG"
  grep -q ".local/opt/llama.cpp" "$SSH_LOG"
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

# ─── per-host defaults ──────────────────────────────────────────────────────

@test "the remote decodes on the GPU at float16 over 24 threads" {
  _run "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q -- "--device cuda" "$SSH_LOG"
  grep -q -- "--compute-type float16" "$SSH_LOG"
  grep -q -- "--threads 24" "$SSH_LOG"
}

@test "--local decodes on the CPU at int8 over 12 threads" {
  _run --local "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q -- "--device cpu" "$UV_LOG"
  grep -q -- "--compute-type int8" "$UV_LOG"
  grep -q -- "--threads 12" "$UV_LOG"
}

@test "--model and --language reach the payload" {
  _run --model some/model --language en "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q -- "--model some/model" "$SSH_LOG"
  grep -q -- "--language en" "$SSH_LOG"
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
  grep -q -- "--speakers 3" "$SSH_LOG"
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
  grep -q -- "diarize .*--threads 24" "$SSH_LOG"
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

@test "the remote scratch is removed on exit" {
  _run "$AUDIO"
  [ "$status" -eq 0 ]
  grep -q -- "rm -rf" "$SSH_LOG"
  [ ! -e "${STATE}/scratch" ]
}

@test "a scratch the driver could not remove is reported rather than claimed gone" {
  RM_UNREACHABLE=1 _run "$AUDIO"
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
