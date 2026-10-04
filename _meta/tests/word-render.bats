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
dest=${paths[$last]}
dest=${dest#*:}
i=0
while [ "$i" -lt "$last" ]; do
  src=${paths[$i]#*:}
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
[ -z "${RASTER_FAILS:-}" ] || exit 1
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
  printf 'mode=%s\npages=%s\ncaptures=%s\nbuild=16.0.20326\ncaption=%s\ndeclared=%s\nmissing=%s\n' \
    "$mode" "${STUB_PAGES:-13}" "$captures" "${STUB_CAPTION:-Word}" \
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
  local cmd
  for cmd in base64 basename cat cp dirname git iconv ls mkdir mktemp mv printf readlink rm sed sleep touch tr awk; do
    [ -e "/usr/bin/${cmd}" ] && ln -s "/usr/bin/${cmd}" "${STUBS}/${cmd}"
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
    SCP_FAILS="${SCP_FAILS:-}" RASTER_FAILS="${RASTER_FAILS:-}" \
    TASK_ABSENT="${TASK_ABSENT:-}" TASK_STATE="${TASK_STATE:-}" TASK_ARGS="${TASK_ARGS:-}" \
    TRIGGER_FAILS="${TRIGGER_FAILS:-}" WORD_FAILS="${WORD_FAILS:-}" NO_RESULT="${NO_RESULT:-}" \
    STUB_PAGES="${STUB_PAGES:-}" STUB_DECLARED="${STUB_DECLARED:-}" STUB_CAPTION="${STUB_CAPTION:-}" \
    STUB_MISSING="${STUB_MISSING:-}" STUB_PDF_PAGES="${STUB_PDF_PAGES:-}" \
    WORD_RENDER_REMOTE="${WORD_RENDER_REMOTE:-}" WORD_RENDER_TASK="${WORD_RENDER_TASK:-}" \
    "$BASH" "$SCRIPT" "$@"
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

# ─── refusals on the remote side ────────────────────────────────────────────

@test "refusal: an unreachable host says so and stages nothing" {
  SSH_UNREACHABLE=1 _run "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot reach"* ]]
  [ ! -e "$SCP_LOG" ]
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

@test "refusal: captures would land on tracked ground" {
  git -C "$STATE" init -q
  _run "$DOCX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"tracked ground"* ]]
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

@test "the job directory is taken fresh and removed on exit" {
  _run "$DOCX"
  [ "$status" -eq 0 ]
  grep -q "rm -rf" "$SSH_LOG"
  grep -q "mkdir -p" "$SSH_LOG"
  [ ! -e "${STATE}/local/word-render" ]
}

@test "a job directory the driver could not remove is reported, not claimed gone" {
  RM_UNREACHABLE=1 _run "$DOCX"
  [[ "$output" == *"could not remove the job directory"* ]]
  [[ "$output" == *"word-render"* ]]
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

@test "--out-dir takes the outputs instead of the project directory" {
  _run --out-dir "${STATE}/elsewhere" "$DOCX"
  [ "$status" -eq 0 ]
  [ -f "${STATE}/elsewhere/report-word.pdf" ]
  [ ! -e "${STATE}/.claude/screenshots/report-word.pdf" ]
}

@test "the report names Word's build and both page counts" {
  _run "$DOCX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Word 16.0.20326"* ]]
  [[ "$output" == *"13 page(s)"* ]]
}

@test "a page count Word and the pdf disagree on is surfaced" {
  STUB_PDF_PAGES=9 _run "$DOCX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"disagree on the page count"* ]]
}

@test "a family the host does not carry makes the pass a fallback render" {
  _run "$DOCX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fallback render: Aptos, Aptos Display"* ]]
  [[ "$output" == *"never Word at the declared metrics"* ]]
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
  grep -q -- "-f 4" "$PDFTOPPM_LOG"
  grep -q -- "-l 6" "$PDFTOPPM_LOG"
}

@test "a single --pages value rasterizes that page alone" {
  _run --pages 3 "$DOCX"
  [ "$status" -eq 0 ]
  grep -q -- "-f 3 -l 3" "$PDFTOPPM_LOG"
}

@test "--dpi reaches pdftoppm and 110 is the default" {
  _run "$DOCX"
  [ "$status" -eq 0 ]
  grep -q -- "-r 110" "$PDFTOPPM_LOG"
  _run --dpi 220 "$DOCX"
  grep -q -- "-r 220" "$PDFTOPPM_LOG"
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

@test "earlier captures are replaced in capture mode too" {
  mkdir -p "${STATE}/.claude/screenshots"
  printf 'old\n' >"${STATE}/.claude/screenshots/report-word-009.png"
  _run --capture "$DOCX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"replacing 1 earlier capture"* ]]
  [ ! -e "${STATE}/.claude/screenshots/report-word-009.png" ]
}

# ─── the payload's session contract ─────────────────────────────────────────

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

@test "the payload fits the whole page rather than the text" {
  grep -q 'Zoom.PageFit = 1' "$PAYLOAD"
}

@test "the payload ends the instance Quit left behind in capture mode" {
  grep -q 'Quit left ' "$PAYLOAD"
  grep -q 'Stop-Process -Id $process.Id -Force' "$PAYLOAD"
}

@test "the capture refuses to take over a Word the user already has open" {
  grep -q 'Word is already running on that desktop' "$PAYLOAD"
}

@test "the payload quits only the Word it started itself" {
  grep -q 'created = -not (Get-Process -Name WINWORD' "$PAYLOAD"
  grep -q 'if ($created) { $word.Quit(0) }' "$PAYLOAD"
}

@test "the payload updates the fields a headless conversion leaves empty" {
  grep -q 'TablesOfContents' "$PAYLOAD"
  grep -q 'Fields.Update()' "$PAYLOAD"
}

@test "the payload writes its sentinel after Word is torn down" {
  result=$(grep -n 'Write-Sentinel $resultPath' "$PAYLOAD" | cut -d: -f1)
  quit=$(grep -n 'if ($created) { $word.Quit(0) }' "$PAYLOAD" | cut -d: -f1)
  [ "$quit" -lt "$result" ]
}
