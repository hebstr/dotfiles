#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2016
# Tests for bin/.local/bin/word-render and the ordering contract of its payload

bats_require_minimum_version 1.5.0

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/word-render"
PAYLOAD="${BATS_TEST_DIRNAME}/../../bin/.local/bin/word-render-payload.ps1"

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
args=()
while [ $# -gt 0 ]; do
  case "$1" in
  -o) shift 2 ;;
  *)
    args+=("$1")
    shift
    ;;
  esac
done
cmd="${args[*]:1}"
printf "%s\n" "${args[*]}" >>"${SSH_LOG}"
[ -z "${SSH_UNREACHABLE:-}" ] || exit 255
case "$cmd" in
*"cat > "*)
  eval "$cmd"
  cp "${cmd#*cat > }" "${REQUEST_LOG}" 2>/dev/null || true
  exit 0
  ;;
*"-e result.txt"*)
  [ -z "${WAIT_UNREACHABLE:-}" ] || exit 255
  [ -z "${JOB_GONE:-}" ] || rm -rf "${STATE}/local/word-render"
  ;;
*"rm -rf"*)
  case "$cmd" in
  *mkdir*) ;;
  *) [ -z "${RM_UNREACHABLE:-}" ] || exit 255 ;;
  esac
  ;;
esac
eval "$cmd"'
}

_install_scp_stub() {
  _stub_command scp '
_remote_unquote() {
  case "$1" in
  *:*)
    set -f
    eval "printf \"%s\" ${1#*:}"
    set +f
    ;;
  *) printf "%s" "$1" ;;
  esac
}
printf "%s\n" "$*" >>"${SCP_LOG}"
[ -z "${SCP_FAILS:-}" ] || exit 1
paths=()
while [ $# -gt 0 ]; do
  case "$1" in
  -o) shift 2 ;;
  -q | -r | -p | --) shift ;;
  *)
    paths+=("$1")
    shift
    ;;
  esac
done
last=$((${#paths[@]} - 1))
dest=$(_remote_unquote "${paths[$last]}")
case "${paths[0]}" in
*:*) [ -z "${SCP_FETCH_FAILS:-}" ] || exit 1 ;;
esac
i=0
while [ "$i" -lt "$last" ]; do
  src=$(_remote_unquote "${paths[$i]}")
  case "$src" in
  *\**)
    for match in $src; do
      [ -e "$match" ] || exit 1
      cp "$match" "$dest" || exit 1
    done
    ;;
  *) cp "$src" "$dest" || exit 1 ;;
  esac
  i=$((i + 1))
done
exit 0'
}

_install_pdf_stubs() {
  _stub_command pdftoppm '
printf "%s\n" "$*" >>"${PDFTOPPM_LOG}"
prefix=${*: -1}
printf "png\n" >"${prefix}-01.png"
printf "png\n" >"${prefix}-02.png"
exit 0'
  _stub_command pdfinfo '
printf "Pages: %s\n" "${STUB_PDF_PAGES:-13}"
exit 0'
}

_install_powershell_stub() {
  local dir="${STUBS}/win32/WindowsPowerShell/v1.0"
  mkdir -p "$dir"
  cat >"${dir}/powershell.exe" <<'STUB'
#!/usr/bin/env bash
encoded=
prev=
for arg in "$@"; do
  [ "$prev" != "-EncodedCommand" ] || encoded=$arg
  prev=$arg
done
script=$(printf '%s' "$encoded" | base64 -d | iconv -f UTF-16LE -t UTF-8)
printf '%s\n----\n' "$script" >>"${PS_LOG}"
job="${STATE}/local/word-render"
case $script in
*'Get-Process LogonUI'*)
  if [ -n "${STUB_SESSION:-}" ]; then
    [ "${STUB_SESSION}" = none ] || printf '%s\n' "${STUB_SESSION}"
  elif [ -n "${STUB_LOCKED:-}" ]; then
    printf 'locked\n'
  else
    printf 'open\n'
  fi
  ;;
*'$env:LOCALAPPDATA'*)
  printf '%s\n' 'C:\Users\julien\AppData\Local'
  ;;
*Get-ScheduledTaskInfo*)
  printf 'state=Ready\nlastResult=267011\nlastRun=2026-10-04 12:00:00\n'
  ;;
*Start-ScheduledTask*)
  [ -z "${TRIGGER_FAILS:-}" ] || exit 1
  if [ -n "${WORD_FAILS:-}" ]; then
    printf 'Documents.Open returned null for input.docx\nat <ScriptBlock>, line 1\n' >"${job}/error.txt"
    exit 0
  fi
  [ -z "${NO_RESULT:-}" ] || exit 0
  mode=$(sed -n 's/^mode=//p' "${job}/request")
  pages=${STUB_PAGES:-13}
  [ "$pages" != "none" ] || pages=
  captures=0
  if [ "$mode" = "capture" ]; then
    for page in 001 002; do
      printf 'png\n' >"${job}/page-${page}.png"
      captures=$((captures + 1))
    done
  else
    pdf=$(sed -n 's/^pdf=//p' "${job}/request")
    printf '%%PDF-1.7 stub\n' >"${job}/${pdf}"
  fi
  missing=${STUB_MISSING:-Aptos;Aptos Display}
  [ "$missing" != "none" ] || missing=
  printf 'mode=%s\npages=%s\ncaptures=%s\nbuild=16.0.20326\ncaption=%s\nfields=%s\ndeclared=%s\nmissing=%s\n' \
    "$mode" "$pages" "$captures" "${STUB_CAPTION:-Word}" "${STUB_FIELDS:-0}" \
    "${STUB_DECLARED:-Aptos;Aptos Display;Courier New}" "$missing" >"${job}/result.txt"
  ;;
*Get-ScheduledTask*)
  [ -z "${TASK_ABSENT:-}" ] || exit 3
  args=${TASK_ARGS:-}
  [ -n "$args" ] || args='-NoProfile -ExecutionPolicy Bypass -File C:\Users\julien\AppData\Local\word-render\word-render-payload.ps1'
  printf '%s\n' "${TASK_STATE:-Ready}"
  printf '%s\n' "$args"
  ;;
esac
exit 0
STUB
  chmod +x "${dir}/powershell.exe"
}

setup() {
  unset WORD_RENDER_REMOTE WORD_RENDER_TASK
  STUBS="$(mktemp -d)"
  STATE="$(mktemp -d)"
  SSH_LOG="$(mktemp -u)"
  SCP_LOG="$(mktemp -u)"
  PS_LOG="$(mktemp -u)"
  PDFTOPPM_LOG="$(mktemp -u)"
  REQUEST_LOG="$(mktemp -u)"
  export STUBS STATE SSH_LOG SCP_LOG PS_LOG PDFTOPPM_LOG REQUEST_LOG
  local cmd path
  for cmd in base64 basename cat cp dirname git iconv ls mkdir mktemp mv printf readlink rm sed sleep touch tr awk; do
    path=$(type -P "$cmd") || {
      printf 'setup: %s is not on the PATH, so the stub PATH would silently lack it\n' "$cmd" >&2
      return 1
    }
    ln -s "$path" "${STUBS}/${cmd}"
  done
  ln -s "$BASH" "${STUBS}/bash"
  _install_ssh_stub
  _install_scp_stub
  _install_pdf_stubs
  _install_powershell_stub
  mkdir -p "${STATE}/local"
  _stub_command wslpath 'printf "%s\n" "${STATE}/local"'
  DOCX="${STATE}/report.docx"
  printf 'PK stub\n' >"$DOCX"
  export DOCX
}

teardown() {
  rm -rf "$STUBS" "$STATE" "$SSH_LOG" "$SCP_LOG" "$PS_LOG" "$PDFTOPPM_LOG" "$REQUEST_LOG"
}

_run() {
  run env PATH="$STUBS" STATE="$STATE" SSH_LOG="$SSH_LOG" SCP_LOG="$SCP_LOG" \
    PS_LOG="$PS_LOG" PDFTOPPM_LOG="$PDFTOPPM_LOG" REQUEST_LOG="$REQUEST_LOG" \
    WIN_SYSTEM32="${STUBS}/win32" \
    SSH_UNREACHABLE="${SSH_UNREACHABLE:-}" RM_UNREACHABLE="${RM_UNREACHABLE:-}" \
    WAIT_UNREACHABLE="${WAIT_UNREACHABLE:-}" JOB_GONE="${JOB_GONE:-}" \
    SCP_FAILS="${SCP_FAILS:-}" SCP_FETCH_FAILS="${SCP_FETCH_FAILS:-}" \
    TASK_ABSENT="${TASK_ABSENT:-}" TASK_STATE="${TASK_STATE:-}" TASK_ARGS="${TASK_ARGS:-}" \
    TRIGGER_FAILS="${TRIGGER_FAILS:-}" WORD_FAILS="${WORD_FAILS:-}" NO_RESULT="${NO_RESULT:-}" \
    STUB_PAGES="${STUB_PAGES:-}" STUB_DECLARED="${STUB_DECLARED:-}" STUB_CAPTION="${STUB_CAPTION:-}" \
    STUB_FIELDS="${STUB_FIELDS:-}" \
    STUB_MISSING="${STUB_MISSING:-}" STUB_PDF_PAGES="${STUB_PDF_PAGES:-}" \
    STUB_LOCKED="${STUB_LOCKED:-}" STUB_SESSION="${STUB_SESSION:-}" \
    WORD_RENDER_REMOTE="${WORD_RENDER_REMOTE:-}" WORD_RENDER_TASK="${WORD_RENDER_TASK:-}" \
    "$BASH" "${SCRIPT_UNDER_TEST:-$SCRIPT}" "$@"
}

# ─── argument handling ──────────────────────────────────────────────────────

@test "--help prints usage and exits 0" {
  _run --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: word-render"* ]]
  [[ "$output" == *"--pages"* ]]
  [[ "$output" == *"WORD_RENDER_REMOTE"* ]]
}

@test "an unknown argument exits 1 and names it" {
  _run --frobnicate "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown argument: --frobnicate"* ]]
}

@test "no document exits 1 and nothing is sent" {
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"no document given"* ]]
  [ ! -e "$SSH_LOG" ]
}

@test "a document that does not exist exits 1 before any ssh" {
  _run "${STATE}/absent.docx"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a file"* ]]
  [ ! -e "$SSH_LOG" ]
}

@test "a file that is not a Word document is refused" {
  printf 'pdf\n' >"${STATE}/report.pdf"
  _run "${STATE}/report.pdf"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a Word document"* ]]
  [ ! -e "$SSH_LOG" ]
}

@test "a macro-enabled document is a Word document too" {
  printf 'PK stub\n' >"${STATE}/memo.docm"
  _run "${STATE}/memo.docm"
  [ "$status" -eq 0 ]
  grep -q "docx=memo.docm" "$REQUEST_LOG"
  [ -f "${STATE}/.claude/screenshots/memo-word.pdf" ]
}

@test "a template is a Word document too" {
  printf 'PK stub\n' >"${STATE}/letterhead.dotx"
  _run "${STATE}/letterhead.dotx"
  [ "$status" -eq 0 ]
  grep -q "docx=letterhead.dotx" "$REQUEST_LOG"
  [ -f "${STATE}/.claude/screenshots/letterhead-word.pdf" ]
}

@test "a driver without its payload beside it refuses before any ssh" {
  cp "$SCRIPT" "${STATE}/word-render"
  SCRIPT_UNDER_TEST="${STATE}/word-render" _run "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"the payload is missing beside this script"* ]]
  [ ! -e "$SSH_LOG" ]
}

@test "a second document is refused rather than silently ignored" {
  printf 'PK\n' >"${STATE}/other.docx"
  _run "$DOCX" "${STATE}/other.docx"
  [ "$status" -eq 1 ]
  [[ "$output" == *"one document at a time"* ]]
}

@test "--pages refuses anything but N or F-L" {
  _run --pages 2x "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--pages takes N or F-L"* ]]
}

@test "--pages refuses a range that ends before it starts" {
  _run --pages 7-3 "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ends before it starts"* ]]
}

@test "--dpi refuses a non-numeric resolution" {
  _run --dpi high "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--dpi takes a number"* ]]
}

@test "--timeout below one poll interval is refused" {
  _run --timeout 1 "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--timeout must be"* ]]
}

@test "--timeout refuses a non-numeric number of seconds" {
  _run --timeout abc "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--timeout takes a number of seconds, got abc"* ]]
}

@test "--pages refuses a page before the first one" {
  _run --pages 0 "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--pages starts at 1, got 0"* ]]
}

@test "--dpi refuses a resolution below one" {
  _run --dpi 0 "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--dpi must be 1 or more, got 0"* ]]
}

@test "a flag left without its operand is named rather than left to set -u" {
  local spec flag want
  for spec in \
    "--pages:needs a page or a F-L range" \
    "--dpi:needs a resolution" \
    "--out-dir:needs a directory" \
    "--timeout:needs a number of seconds"; do
    flag=${spec%%:*}
    want=${spec#*:}
    _run "$flag"
    [ "$status" -eq 1 ]
    [[ "$output" == *"${flag} ${want}"* ]]
    [[ "$output" != *"unbound variable"* ]]
  done
}

@test "an empty --out-dir is refused rather than falling back to the default" {
  _run --out-dir "" "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--out-dir needs a directory"* ]]
  [ ! -e "${STATE}/.claude/screenshots/report-word.pdf" ]
}

# ─── refusals on the remote side ────────────────────────────────────────────

@test "refusal: an unreachable host says so and stages nothing" {
  SSH_UNREACHABLE=1 _run "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot reach"* ]]
  [ ! -e "$SCP_LOG" ]
}

@test "refusal: a capture on a locked session never reaches Word" {
  STUB_LOCKED=1 _run --capture "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is locked"* ]]
  [ ! -e "$SCP_LOG" ]
}

@test "refusal: a session state that comes back silent is not read as open" {
  STUB_SESSION=none _run --capture "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"the session state on ju-TP2 came back as nothing"* ]]
  [ ! -e "$SCP_LOG" ]
}

@test "the pdf route runs on a locked session, which it never photographs" {
  STUB_LOCKED=1 _run "$DOCX"
  [ "$status" -eq 0 ]
  [[ "$output" != *"is locked"* ]]
}

@test "refusal: a missing scheduled task hands back the registration command" {
  TASK_ABSENT=1 _run "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no scheduled task named Claude-WordRender"* ]]
  [[ "$output" == *"EncodedCommand"* ]]
  [ ! -e "$SCP_LOG" ]
}

@test "the registration command carries an interactive logon and no elevation" {
  TASK_ABSENT=1 _run "$DOCX"
  encoded=${output##*EncodedCommand }
  script=$(printf '%s' "$encoded" | base64 -d | iconv -f UTF-16LE -t UTF-8)
  [[ "$script" == *"Register-ScheduledTask"* ]]
  [[ "$script" == *"-LogonType Interactive"* ]]
  [[ "$script" == *"-RunLevel Limited"* ]]
  [[ "$script" == *"word-render-payload.ps1"* ]]
}

@test "refusal: a task already running is not triggered again" {
  TASK_STATE=Running _run "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"already running"* ]]
  [ ! -e "$SCP_LOG" ]
}

@test "refusal: a disabled task is named rather than triggered" {
  TASK_STATE=Disabled _run "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Disabled"* ]]
}

@test "refusal: a task pointing at another payload is refused" {
  TASK_ARGS='-File "C:\Users\julien\elsewhere.ps1"' _run "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not the payload this driver stages"* ]]
  [ ! -e "$SCP_LOG" ]
}

@test "refusal: a task that will not start is surfaced" {
  TRIGGER_FAILS=1 _run "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"would not start"* ]]
}

@test "refusal: Word's own error is relayed rather than a timeout" {
  WORD_FAILS=1 _run "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Word refused the document"* ]]
  [[ "$output" == *"Documents.Open returned null"* ]]
}

@test "a silent Word is reported with the task's last result" {
  NO_RESULT=1 _run --timeout 2 "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no result after 2s"* ]]
  [[ "$output" == *"lastResult=267011"* ]]
}

@test "refusal: captures would land on ground git does not ignore" {
  git -C "$STATE" init -q
  _run "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not ignored in"* ]]
  [ ! -e "$SSH_LOG" ]
}

@test "an ignored screenshots directory passes the guard" {
  git -C "$STATE" init -q
  printf '.claude/\n' >"${STATE}/.gitignore"
  _run "$DOCX"
  [ "$status" -eq 0 ]
  [ -f "${STATE}/.claude/screenshots/report-word.pdf" ]
}

# ─── the staged job ─────────────────────────────────────────────────────────

@test "the payload and the document are staged in the job directory" {
  _run "$DOCX"
  [ "$status" -eq 0 ]
  grep -q "word-render-payload.ps1" "$SCP_LOG"
  grep -q "report.docx" "$SCP_LOG"
}

@test "the request names the document and the pdf the payload must write" {
  _run "$DOCX"
  [ "$status" -eq 0 ]
  grep -q "docx=report.docx" "$REQUEST_LOG"
  grep -q "pdf=report-word.pdf" "$REQUEST_LOG"
}

@test "the job directory is removed on exit" {
  _run "$DOCX"
  [ "$status" -eq 0 ]
  [ ! -e "${STATE}/local/word-render" ]
}

@test "the job directory is taken fresh, so an earlier result is not read as this one" {
  mkdir -p "${STATE}/local/word-render"
  printf 'mode=pdf\npages=99\ncaptures=0\nbuild=16.0.0\n' >"${STATE}/local/word-render/result.txt"
  NO_RESULT=1 _run --timeout 2 "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no result after 2s"* ]]
  [[ "$output" != *"99 page(s)"* ]]
}

@test "a job directory the driver could not remove is reported, not claimed gone" {
  RM_UNREACHABLE=1 _run "$DOCX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"could not remove the job directory"* ]]
  [[ "$output" == *'C:\Users\julien\AppData\Local\word-render on'* ]]
}

@test "a timed-out render keeps the job directory for the diagnosis" {
  NO_RESULT=1 _run --timeout 2 "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *'C:\Users\julien\AppData\Local\word-render is left in place'* ]]
  [ -d "${STATE}/local/word-render" ]
}

@test "a host that drops during the wait keeps the job directory too" {
  WAIT_UNREACHABLE=1 _run "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot reach"* ]]
  [[ "$output" == *'C:\Users\julien\AppData\Local\word-render is left in place'* ]]
  [ -d "${STATE}/local/word-render" ]
}

@test "a job directory claimed away during the wait is named as gone" {
  JOB_GONE=1 _run "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *'C:\Users\julien\AppData\Local\word-render is gone on'* ]]
  [[ "$output" == *"another render may have claimed it"* ]]
  [[ "$output" != *"is left in place"* ]]
}

@test "a failing render still tears the job directory down" {
  WORD_FAILS=1 _run "$DOCX"
  [ "$status" -ne 0 ]
  [ ! -e "${STATE}/local/word-render" ]
}

@test "the driver never activates Word COM from the ssh session" {
  _run "$DOCX"
  [ "$status" -eq 0 ]
  run ! grep -q "Word.Application" "$PS_LOG"
}

@test "the task is reached by name through the scheduler, not by a shell on Word" {
  _run "$DOCX"
  [ "$status" -eq 0 ]
  grep -q "Start-ScheduledTask -TaskName 'Claude-WordRender'" "$PS_LOG"
}

@test "WORD_RENDER_TASK names another task" {
  WORD_RENDER_TASK=Other-Task _run "$DOCX"
  [ "$status" -eq 0 ]
  grep -q "Start-ScheduledTask -TaskName 'Other-Task'" "$PS_LOG"
}

@test "WORD_RENDER_REMOTE names another host" {
  WORD_RENDER_REMOTE=other-host _run "$DOCX"
  [ "$status" -eq 0 ]
  grep -q "other-host" "$SSH_LOG"
  run ! grep -q "ju-TP2" "$SSH_LOG"
}

# ─── what comes back ────────────────────────────────────────────────────────

@test "the pdf and its captures land in the project's screenshots directory" {
  _run "$DOCX"
  [ "$status" -eq 0 ]
  [ -f "${STATE}/.claude/screenshots/report-word.pdf" ]
  [ -f "${STATE}/.claude/screenshots/report-word-01.png" ]
  [[ "$output" == *"report-word-01.png"* ]]
}

@test "a document name with a space comes back through the quoted remote path" {
  printf 'PK stub\n' >"${STATE}/mon rapport final.docx"
  _run "${STATE}/mon rapport final.docx"
  [ "$status" -eq 0 ]
  [ -f "${STATE}/.claude/screenshots/mon rapport final-word.pdf" ]
  [ -f "${STATE}/.claude/screenshots/mon rapport final-word-01.png" ]
}

@test "a document in a subdirectory still lands at the repository root" {
  git -C "$STATE" init -q
  printf '.claude/\n' >"${STATE}/.gitignore"
  mkdir -p "${STATE}/rapports/2026"
  printf 'PK stub\n' >"${STATE}/rapports/2026/note.docx"
  _run "${STATE}/rapports/2026/note.docx"
  [ "$status" -eq 0 ]
  [ -f "${STATE}/.claude/screenshots/note-word.pdf" ]
  [ ! -e "${STATE}/rapports/2026/.claude/screenshots/note-word.pdf" ]
}

@test "--out-dir takes the outputs instead of the project directory" {
  _run --out-dir "${STATE}/elsewhere" "$DOCX"
  [ "$status" -eq 0 ]
  [ -f "${STATE}/elsewhere/report-word.pdf" ]
  [ ! -e "${STATE}/.claude/screenshots/report-word.pdf" ]
}

@test "refusal: an --out-dir in another repository is guarded too" {
  git -C "$STATE" init -q
  mkdir -p "${STATE}/other"
  git -C "${STATE}/other" init -q
  _run --out-dir "${STATE}/other/captures" "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"${STATE}/other/captures is not ignored in ${STATE}/other"* ]]
  [ ! -e "${STATE}/other/captures/report-word.pdf" ]
}

@test "a relative --out-dir is resolved before the ignore guard reads it" {
  git -C "$STATE" init -q
  cd "$STATE"
  [ "$PWD" = "$STATE" ]
  _run --out-dir captures "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"${STATE}/captures is not ignored in ${STATE}"* ]]
  [ ! -e "${STATE}/captures/report-word.pdf" ]
}

@test "the report names Word's build and both page counts" {
  _run "$DOCX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Word 16.0.20326"* ]]
  [[ "$output" == *"13 page(s)"* ]]
}

@test "a page count Word and the pdf disagree on is surfaced" {
  STUB_PAGES=13 STUB_PDF_PAGES=9 _run "$DOCX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"counts 13 page(s), the PDF carries 9"* ]]
  [[ "$output" == *"disagree on the page count"* ]]
}

@test "a result without a page count is refused rather than rasterized" {
  STUB_PAGES=none _run "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"reported no page count"* ]]
  [ ! -e "$PDFTOPPM_LOG" ]
}

@test "a family the host does not carry makes the pass a fallback render" {
  _run "$DOCX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fallback render: Aptos, Aptos Display"* ]]
  [[ "$output" == *"never Word at the declared metrics"* ]]
}

@test "a field that refused to update is said rather than passing for a clean render" {
  STUB_FIELDS=7 _run "$DOCX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"at least one field refused to update"* ]]
}

@test "fields all updated say nothing" {
  _run "$DOCX"
  [ "$status" -eq 0 ]
  [[ "$output" != *"refused to update"* ]]
}

@test "every family installed is said plainly rather than left silent" {
  STUB_MISSING=none STUB_DECLARED="Calibri;Courier New" _run "$DOCX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"every declared family is installed"* ]]
  [[ "$output" == *"Calibri, Courier New"* ]]
}

@test "--pages hands pdftoppm the range and nothing wider" {
  _run --pages 4-6 "$DOCX"
  [ "$status" -eq 0 ]
  grep -q -- "-f 4 -l 6" "$PDFTOPPM_LOG"
}

@test "a single --pages value rasterizes that page alone" {
  _run --pages 3 "$DOCX"
  [ "$status" -eq 0 ]
  grep -q -- "-f 3 -l 3" "$PDFTOPPM_LOG"
}

@test "110 is the default rasterization resolution" {
  _run "$DOCX"
  [ "$status" -eq 0 ]
  grep -q -- "-r 110" "$PDFTOPPM_LOG"
}

@test "--dpi replaces the default rather than adding to it" {
  _run --dpi 220 "$DOCX"
  [ "$status" -eq 0 ]
  grep -q -- "-r 220" "$PDFTOPPM_LOG"
  run ! grep -q -- "-r 110" "$PDFTOPPM_LOG"
}

@test "earlier captures of the same document are replaced, not added to" {
  mkdir -p "${STATE}/.claude/screenshots"
  printf 'old\n' >"${STATE}/.claude/screenshots/report-word-07.png"
  _run "$DOCX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"replacing 1 earlier capture"* ]]
  [ ! -e "${STATE}/.claude/screenshots/report-word-07.png" ]
}

@test "a staging failure refuses before Word is ever triggered" {
  SCP_FAILS=1 _run "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not stage"* ]]
  run ! grep -q "Start-ScheduledTask" "$PS_LOG"
  [ ! -e "$PDFTOPPM_LOG" ]
}

@test "a pdf that will not come back is refused rather than rasterized" {
  SCP_FETCH_FAILS=1 _run "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not bring report-word.pdf back"* ]]
  [ ! -e "${STATE}/.claude/screenshots/report-word.pdf" ]
  [ ! -e "$PDFTOPPM_LOG" ]
}

# ─── the capture route ──────────────────────────────────────────────────────

@test "--capture asks the payload for a capture and never rasterizes a pdf" {
  _run --capture "$DOCX"
  [ "$status" -eq 0 ]
  grep -q "mode=capture" "$REQUEST_LOG"
  [ ! -e "$PDFTOPPM_LOG" ]
  [ ! -e "${STATE}/.claude/screenshots/report-word.pdf" ]
}

@test "the captures land under the document's own name" {
  _run --capture "$DOCX"
  [ "$status" -eq 0 ]
  [ -f "${STATE}/.claude/screenshots/report-word-001.png" ]
  [ -f "${STATE}/.claude/screenshots/report-word-002.png" ]
  [[ "$output" == *"2 brought back as screen captures"* ]]
}

@test "the default route stays the pdf export" {
  _run "$DOCX"
  [ "$status" -eq 0 ]
  grep -q "mode=pdf" "$REQUEST_LOG"
  [ -f "${STATE}/.claude/screenshots/report-word.pdf" ]
}

@test "--pages reaches the payload in capture mode rather than pdftoppm" {
  _run --capture --pages 4-6 "$DOCX"
  [ "$status" -eq 0 ]
  grep -q "first=4" "$REQUEST_LOG"
  grep -q "last=6" "$REQUEST_LOG"
  [ ! -e "$PDFTOPPM_LOG" ]
}

@test "a capture from an unlicensed Word says so rather than passing for a render" {
  STUB_CAPTION="Word (Unlicensed Product)" _run --capture "$DOCX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"that Word is unlicensed"* ]]
  [[ "$output" == *"it writes no file"* ]]
}

@test "captures that never come back are refused rather than reported as written" {
  SCP_FETCH_FAILS=1 _run --capture "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no capture came back"* ]]
  run ! grep -q "wrote " <<<"$output"
}

@test "a document name with a space lands under that name in capture mode too" {
  printf 'PK stub\n' >"${STATE}/mon rapport final.docx"
  _run --capture "${STATE}/mon rapport final.docx"
  [ "$status" -eq 0 ]
  [ -f "${STATE}/.claude/screenshots/mon rapport final-word-001.png" ]
}

@test "earlier captures are replaced in capture mode too" {
  mkdir -p "${STATE}/.claude/screenshots"
  printf 'old\n' >"${STATE}/.claude/screenshots/report-word-009.png"
  _run --capture "$DOCX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"replacing 1 earlier capture"* ]]
  [ ! -e "${STATE}/.claude/screenshots/report-word-009.png" ]
}

# ─── the payload's session contract ─────────────────────────────────────────

@test "a preamble failure lands in the error sentinel rather than passing for a wedged Word" {
  try=$(grep -n '^try {' "$PAYLOAD" | cut -d: -f1)
  interop=$(grep -n 'Add-Type $interop' "$PAYLOAD" | cut -d: -f1)
  drawing=$(grep -n 'Add-Type -AssemblyName System.Drawing' "$PAYLOAD" | cut -d: -f1)
  [ "$try" -lt "$interop" ]
  [ "$try" -lt "$drawing" ]
}

@test "the payload asserts the interactive session before touching Word" {
  guard=$(grep -n "UserInteractive" "$PAYLOAD" | head -1 | cut -d: -f1)
  activation=$(grep -n "New-Object -ComObject Word.Application" "$PAYLOAD" | head -1 | cut -d: -f1)
  [ -n "$guard" ]
  [ -n "$activation" ]
  [ "$guard" -lt "$activation" ]
}

@test "the payload refuses an unlicensed Word before opening the document" {
  guard=$(grep -n "caption -match 'Unlicensed'" "$PAYLOAD" | head -1 | cut -d: -f1)
  open=$(grep -n 'word.Documents.Open(' "$PAYLOAD" | head -1 | cut -d: -f1)
  [ -n "$guard" ]
  [ "$guard" -lt "$open" ]
}

@test "the licence refusal spares the capture route, which an unlicensed Word still serves" {
  grep -q "mode -eq 'pdf' -and \$caption -match 'Unlicensed'" "$PAYLOAD"
}

@test "the payload hides the sign-in overlay rather than closing it" {
  grep -q 'ShowWindow($handle, 0)' "$PAYLOAD"
  run ! grep -q 'PostMessage' "$PAYLOAD"
}

@test "the payload pages by screenfuls, which alone frames a page from its top edge" {
  grep -q 'VerticalPercentScrolled = 0' "$PAYLOAD"
  grep -q 'LargeScroll($page - 1, 0, 0, 0)' "$PAYLOAD"
  run ! grep -q 'ScrollIntoView' "$PAYLOAD"
}

@test "the payload refuses a page whose foreground is not its own Word" {
  grep -q 'GetForegroundWindow' "$PAYLOAD"
  grep -q 'Assert-Foreground $handle $ours' "$PAYLOAD"
  assert=$(grep -n 'Assert-Foreground $handle $ours' "$PAYLOAD" | cut -d: -f1)
  save=$(grep -n 'size = Save-Window $handle' "$PAYLOAD" | cut -d: -f1)
  [ "$assert" -lt "$save" ]
}

@test "the payload refuses two pages that scroll to the same place" {
  grep -q 'position = $window.ActivePane.VerticalPercentScrolled' "$PAYLOAD"
  grep -q 'scrolled no further than page' "$PAYLOAD"
}

@test "the duplicate check stands down where the integer percent cannot discriminate" {
  grep -q 'step = 100 / \[Math\]::Max(1, $pages - 1)' "$PAYLOAD"
  grep -q 'discriminates = ($step -ge 2)' "$PAYLOAD"
  grep -q 'if ($discriminates -and $position -le $previous)' "$PAYLOAD"
}

@test "the payload shows Word for the capture alone, which photographs its window" {
  grep -qF "\$word.Visible = (\$mode -eq 'capture')" "$PAYLOAD"
}

@test "the payload repaginates before it counts the pages the report rests on" {
  repaginate=$(grep -n 'Repaginate()' "$PAYLOAD" | cut -d: -f1)
  count=$(grep -n 'ComputeStatistics(2)' "$PAYLOAD" | cut -d: -f1)
  [ -n "$repaginate" ]
  [ "$repaginate" -lt "$count" ]
}

@test "an export that wrote no file refuses before the success sentinel" {
  exported=$(grep -n 'ExportAsFixedFormat(' "$PAYLOAD" | cut -d: -f1)
  guard=$(grep -n 'ExportAsFixedFormat wrote no file' "$PAYLOAD" | cut -d: -f1)
  result=$(grep -n 'Write-Sentinel $resultPath' "$PAYLOAD" | cut -d: -f1)
  [ -n "$guard" ]
  [ "$exported" -lt "$guard" ]
  [ "$guard" -lt "$result" ]
}

@test "the payload fits the whole page rather than the text" {
  grep -qF '$window.ActivePane.View.Zoom.PageFit = 1' "$PAYLOAD"
}

@test "the payload ends the instance Quit left behind in capture mode" {
  grep -q 'Quit left ' "$PAYLOAD"
  grep -q 'Stop-Process -Id $process.Id -Force' "$PAYLOAD"
}

@test "the capture refuses to take over a Word the user already has open" {
  grep -qF "if (\$mode -eq 'capture' -and -not \$created) {" "$PAYLOAD"
  grep -qF 'Word is already running on that desktop' "$PAYLOAD"
  guard=$(grep -nF "if (\$mode -eq 'capture' -and -not \$created) {" "$PAYLOAD" | cut -d: -f1)
  activation=$(grep -nF 'New-Object -ComObject Word.Application' "$PAYLOAD" | cut -d: -f1)
  [ "$guard" -lt "$activation" ]
}

@test "the payload quits only the Word it started itself" {
  grep -q 'created = ($before.Count -eq 0)' "$PAYLOAD"
  grep -q 'if ($created -and -not $shared) { $word.Quit(0) }' "$PAYLOAD"
}

@test "the payload ends the pids it opened and spares a document that joined" {
  grep -q 'shared = ($word.Documents.Count -gt 0)' "$PAYLOAD"
  grep -q 'Get-Process -Id $ours' "$PAYLOAD"
  run ! grep -q 'left = @(Get-Process -Name WINWORD' "$PAYLOAD"
}

@test "the payload updates the fields a headless conversion leaves empty" {
  grep -qF 'foreach ($toc in $doc.TablesOfContents) { $toc.Update() }' "$PAYLOAD"
  grep -qF 'fieldError = $doc.Fields.Update()' "$PAYLOAD"
  grep -q '"fields=$fieldError"' "$PAYLOAD"
}

@test "the payload reaches the fields outside the main story without dying on them" {
  grep -q 'foreach ($story in $doc.StoryRanges)' "$PAYLOAD"
  grep -q 'range = $range.NextStoryRange' "$PAYLOAD"
  grep -q 'refused its field update' "$PAYLOAD"
}

@test "the sentinel appears whole or not at all" {
  grep -q 'staging = $Path' "$PAYLOAD"
  grep -q 'IO.File\]::Move($staging, $Path)' "$PAYLOAD"
  run ! grep -q 'IO.File\]::WriteAllText($Path' "$PAYLOAD"
}

@test "the payload writes its sentinel after Word is torn down" {
  result=$(grep -n 'Write-Sentinel $resultPath' "$PAYLOAD" | cut -d: -f1)
  quit=$(grep -n 'if ($created -and -not $shared) { $word.Quit(0) }' "$PAYLOAD" | cut -d: -f1)
  [ "$quit" -lt "$result" ]
}
