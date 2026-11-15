#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2086

bats_require_minimum_version 1.5.0

# Pins zotero-skill.sh of the zotero skill: what each subcommand prints, and which
# failure exits with which status rather than with an empty result. Traps that
# drive the harness:
#   1. no test needs a running Zotero: a curl shim on PATH serves a fixture
#      library and emulates what the script depends on (the Total-Results
#      header with CRLF line ends, limit and start paging, STUB_CAP capping the
#      page size below the requested limit, a 404 for the children of a trashed
#      parent). It answers 599 to any curl argument the script is not meant to
#      use, so a non-GET request or a new flag fails a test instead of passing;
#   2. the shim is on PATH only inside z(), so the live smoke tests at the end
#      reach the real curl and the real API, and skip when it answers 000;
#   3. the fixture API shape is an assumption, which the live smoke tests pin
#      field by field against the real library;
#   4. a negative assertion is written run -1 rg or run !, never a bare "! cmd":
#      bats runs a test under errexit, which a negated command does not trip;
#   5. the guard only reads the first HEAD_BYTES (5000) of a cache, so the two
#      depth tests place a DOI on each side of that line and the multibyte test
#      puts the cut inside a two-byte character.

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/skills/zotero/scripts/zotero-skill.sh"

setup() {
  FIX="$BATS_TEST_TMPDIR/fixture"
  STORE="$BATS_TEST_TMPDIR/storage"
  STUBS="$BATS_TEST_TMPDIR/bin"
  CALLS="$BATS_TEST_TMPDIR/calls.log"
  API_URL="http://stub.invalid/api/users/0"
  export FIX STORE STUBS CALLS API_URL
  mkdir -p "$FIX" "$STORE" "$STUBS"
  : >"$CALLS"
  make_shim
  build_library
}

make_shim() {
  cat >"$STUBS/curl" <<'SHIM'
#!/usr/bin/env bash
out=
hdr=
url=
while (($#)); do
  case $1 in
    -s) ;;
    -o) out=$2; shift ;;
    -D) hdr=$2; shift ;;
    -w | -m | --connect-timeout) shift ;;
    http*) url=$1 ;;
    *) printf 'unexpected curl argument: %s\n' "$1" >>"$CALLS"; printf 599; exit 0 ;;
  esac
  shift
done
printf '%s\n' "$url" >>"$CALLS"
if [[ -n ${STUB_DOWN-} ]]; then printf 000; exit 7; fi
if [[ -n ${STUB_CODE-} ]]; then printf '%s' "$STUB_CODE"; exit 0; fi
rest=${url#"$ZOTERO_API"/}
path=${rest%%\?*}
query=
[[ $rest == *\?* ]] && query=${rest#*\?}
limit=100000
start=0
[[ $query =~ limit=([0-9]+) ]] && limit=${BASH_REMATCH[1]}
[[ $query =~ start=([0-9]+) ]] && start=${BASH_REMATCH[1]}
[[ -n ${STUB_CAP-} ]] && ((limit > STUB_CAP)) && limit=$STUB_CAP
case $path in
  items/top) file=top.json ;;
  items/trash) file=trash.json ;;
  items) file=att.json ;;
  items/*/children) k=${path#items/}; file=children-${k%/children}.json ;;
  *) printf 404; exit 0 ;;
esac
if [[ ! -f $FIX/$file ]]; then printf 404; exit 0; fi
total=${STUB_TOTAL:-$(jq length "$FIX/$file")}
jq -c --argjson s "$start" --argjson l "$limit" '.[$s:$s+$l]' "$FIX/$file" >"$out"
if [[ -n ${STUB_BODY+x} ]]; then printf '%s' "$STUB_BODY" >"$out"; fi
if [[ -z ${STUB_NO_TOTAL-} ]]; then
  printf 'HTTP/1.1 200 OK\r\nTotal-Results: %s\r\n\r\n' "$total" >"$hdr"
else
  printf 'HTTP/1.1 200 OK\r\n\r\n' >"$hdr"
fi
printf 200
SHIM
  chmod +x "$STUBS/curl"
}

add_top() {
  local extra=${8-}
  [[ -n $extra ]] || extra='{}'
  jq -n -c --arg key "$1" --arg ck "$2" --arg type "$3" --arg title "$4" --arg date "$5" \
    --arg doi "$6" --arg last "$7" --argjson extra "$extra" '
    {key: $key, data: ({key: $key, itemType: $type, title: $title}
      + (if $ck == "" then {} else {citationKey: $ck} end)
      + (if $date == "" then {} else {date: $date} end)
      + (if $doi == "" then {} else {DOI: $doi} end)
      + {creators: (if $last == "" then [] else [{creatorType: "author", firstName: "A", lastName: $last}] end)}
      + $extra)}' >>"$FIX/top.ndjson"
}

add_trashed_parent() {
  jq -n -c --arg key "$1" --arg ck "$2" --arg title "$3" --argjson deleted "$4" '
    {key: $key, data: {key: $key, itemType: "journalArticle", citationKey: $ck, title: $title,
      date: "2015", deleted: $deleted, creators: [{creatorType: "author", lastName: "Gone"}]}}' >>"$FIX/trash.ndjson"
}

attach() {
  local parent=$1 key=$2 mode=${3:-imported_file} where=${4:-live} item
  item=$(jq -n -c --arg key "$key" --arg parent "$parent" --arg mode "$mode" --arg where "$where" '
    {key: $key, data: ({key: $key, itemType: "attachment", parentItem: $parent, contentType: "application/pdf",
      linkMode: $mode, filename: ($key + ".pdf")} + (if $where == "trash" then {deleted: 1} else {} end))}')
  if [[ $where == trash ]]; then
    printf '%s\n' "$item" >>"$FIX/trash.ndjson"
  else
    printf '%s\n' "$item" >>"$FIX/att.ndjson"
    printf '%s\n' "$item" >>"$FIX/children-$parent.ndjson"
  fi
}

cache_text() {
  mkdir -p "$STORE/$1"
  printf '%s\n' "$2" >"$STORE/$1/.zotero-ft-cache"
}

finish_library() {
  local f name
  for name in top trash att; do
    if [[ -f $FIX/$name.ndjson ]]; then jq -s . "$FIX/$name.ndjson" >"$FIX/$name.json"; else printf '[]' >"$FIX/$name.json"; fi
  done
  for f in "$FIX"/children-*.ndjson; do
    [[ -e $f ]] || continue
    jq -s . "$f" >"${f%.ndjson}.json"
  done
}

build_library() {
  add_top N1 smith2020 journalArticle "Quantifying hospital readmission patterns with propensity methods" 2020-05-01 10.1000/xyz123 Smith
  attach N1 S1
  cache_text S1 "Journal of Health Services
Quantifying hospital readmission patterns with propensity methods
John Smith. DOI: 10.1000/XYZ123. Published 2020"

  add_top N2 jones2019 journalArticle "Bayesian hierarchical estimation of treatment effects" 2019 "" Jones
  attach N2 J1
  cache_text J1 "Coral reef bleaching and thermal tolerance in the Great Barrier Reef
Casarotti et al. 2014. Marine Ecology Progress Series"

  add_top N3 lee2021 preprint "Scaling language models for clinical extraction" 2021-01-03 10.48550/arXiv.2101.00001 Lee '{"repository":"arXiv"}'
  attach N3 L1
  cache_text L1 "arXiv:2101.00001v1 [cs.CL] 3 Jan 2021
Scaling language models for clinical extraction
Soo Lee"

  add_top N4 kim2018 journalArticle "A plain journal article without any preprint trait" 2018 10.1016/j.example.2018.01 Kim
  add_top N5 wu2023 webpage "A page hosted on arxiv" 2023 "" Wu '{"url":"https://arxiv.org/abs/2301.00001"}'
  add_top N6 chan2020 journalArticle "An SSRN working paper" 2020 10.2139/ssrn.123456 Chan
  add_top N7 ruiz2021 journalArticle "A Research Square paper" 2021 10.21203/rs.3.rs-100/v1 Ruiz
  add_top N8 park2022 journalArticle "A bioRxiv paper" 2022 10.1101/2022.01.01.000001 Park
  add_top N9 nopdf2018 journalArticle "A notice with no attachment" 2018 "" Nopdf

  add_top N10 linked2017 journalArticle "A notice with a linked PDF only" 2017 "" Linked
  attach N10 LK1 linked_url

  add_top N11 nocache2016 journalArticle "A notice whose PDF has no cache yet" 2016 "" Nocache
  attach N11 NC1

  add_top N12 multi2020 journalArticle "Realistic evaluation of survival estimators" 2020 "" Multi
  attach N12 M1
  attach N12 M2
  cache_text M1 "PRISMA 2020 checklist
Section and topic. Item. Checklist item. Location where item is reported"
  cache_text M2 "Realistic evaluation of survival estimators
Anna Multi. 2020"

  finish_library
}

z() {
  env PATH="$STUBS:$PATH" ZOTERO_API="$API_URL" ZOTERO_STORAGE="$STORE" CALLS="$CALLS" FIX="$FIX" \
    ${STUB_DOWN:+STUB_DOWN=1} ${STUB_CODE:+STUB_CODE=$STUB_CODE} ${STUB_CAP:+STUB_CAP=$STUB_CAP} \
    ${STUB_NO_TOTAL:+STUB_NO_TOTAL=1} ${STUB_TOTAL:+STUB_TOTAL=$STUB_TOTAL} \
    ${STUB_BODY+STUB_BODY=$STUB_BODY} bash "$SCRIPT" "$@"
}

@test "keys prints every notice as four TSV columns sorted by citation key" {
  run -0 --separate-stderr z keys
  [ "${#lines[@]}" -eq 12 ]
  [ "${lines[0]}" = $'chan2020\tjournalArticle\t10.2139/ssrn.123456\tAn SSRN working paper' ]
  [ "${lines[1]}" = $'jones2019\tjournalArticle\t\tBayesian hierarchical estimation of treatment effects' ]
  [ "${lines[11]%%$'\t'*}" = wu2023 ]
}

@test "keys collapses a tab or newline inside a title to a space" {
  add_top N20 tabbed2000 journalArticle $'One\ttwo\nthree' 2000 "" Tab
  finish_library
  run -0 --separate-stderr z keys
  [[ $output == *$'tabbed2000\tjournalArticle\t\tOne two three'* ]]
}

@test "keys lists a notice without citation key with an empty first column" {
  add_top N21 "" journalArticle "No key yet" 2000 "" Nokey
  finish_library
  run -0 --separate-stderr z keys
  [ "${lines[0]}" = $'\tjournalArticle\t\tNo key yet' ]
}

@test "keys pages by start while the Total-Results header exceeds what came back" {
  STUB_CAP=5 run -0 --separate-stderr z keys
  [ "${#lines[@]}" -eq 12 ]
  rg -q 'start=5' "$CALLS"
  rg -q 'start=10' "$CALLS"
  run -1 rg -q 'start=15' "$CALLS"
}

@test "keys makes one call when the whole library fits one page" {
  run -0 --separate-stderr z keys
  [ "$(rg -c 'items/top' "$CALLS")" -eq 1 ]
  rg -q 'limit=500' "$CALLS"
}

@test "every request is a GET on the configured API, with no argument the shim refuses" {
  z keys >/dev/null
  z cache smith2020 >/dev/null 2>&1
  z grep propensity >/dev/null 2>&1
  z trash >/dev/null
  run -1 rg -q 'unexpected curl argument' "$CALLS"
  run -1 rg -v '^http://stub\.invalid/api/users/0/' "$CALLS"
  run -1 rg -q 'json-rpc|better-bibtex' "$CALLS"
}

@test "no curl line of the script carries a write flag" {
  local curl_lines
  curl_lines=$(rg '\bcurl\b' "$SCRIPT")
  run -1 rg -e ' -X' -e ' --data' -e ' -d ' -e ' -T ' -e ' --json' -e ' --upload' -e 'json-rpc' <<<"$curl_lines"
}

@test "a dead API exits 3 on every subcommand with a message and no output" {
  local sub
  export STUB_DOWN=1
  for sub in keys trash preprints "cache smith2020" "grep propensity"; do
    run -3 --separate-stderr z $sub
    [ -z "$output" ]
    # shellcheck disable=SC2154
    [[ $stderr == *"does not answer"* ]]
  done
}

@test "an HTTP error exits 6" {
  STUB_CODE=500 run -6 --separate-stderr z keys
  [[ $stderr == *"HTTP 500"* ]]
}

@test "a response with no Total-Results header exits 6" {
  STUB_NO_TOTAL=1 run -6 --separate-stderr z keys
  [[ $stderr == *"Total-Results"* ]]
}

@test "an empty page before Total-Results is reached exits 6 instead of truncating" {
  STUB_TOTAL=30 run -6 --separate-stderr z keys
  [ -z "$output" ]
  [[ $stderr == *"empty page"* ]]
}

@test "a 200 with an empty body exits 6" {
  STUB_BODY='' run -6 --separate-stderr z keys
  [ -z "$output" ]
  [[ $stderr == *"unreadable JSON"* ]]
}

@test "a 200 whose body is not a JSON array exits 6" {
  STUB_BODY='{"a":1,"b":2}' run -6 --separate-stderr z keys
  [ -z "$output" ]
  [[ $stderr == *"unreadable JSON"* ]]
}

@test "no argument, an unknown subcommand and a missing argument exit 2" {
  run -2 --separate-stderr z
  run -2 --separate-stderr z nope
  run -2 --separate-stderr z cache
  run -2 --separate-stderr z grep
  run -0 --separate-stderr z --help
  [[ $output == *"usage: zotero-skill.sh"* ]]
}

@test "trash lists trashed parents only, with item key and deleted flag" {
  add_trashed_parent T1 gone2015 "A trashed article" true
  add_trashed_parent T2 gone2016 "Another one" 1
  attach T1 TA1 imported_file trash
  finish_library
  run -0 --separate-stderr z trash
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = $'gone2015\tT1\tjournalArticle\ttrue\tA trashed article' ]
  [ "${lines[1]}" = $'gone2016\tT2\tjournalArticle\t1\tAnother one' ]
}

@test "trash of an empty trash prints nothing and exits 0" {
  run -0 --separate-stderr z trash
  [ -z "$output" ]
}

@test "preprints finds itemType, the four DOI prefixes and arXiv URLs, and spares the rest" {
  run -0 --separate-stderr z preprints "$BATS_TEST_TMPDIR"
  [ "${#lines[@]}" -eq 5 ]
  [[ ${lines[0]} == chan2020$'\t'0$'\t'* ]]
  [[ ${lines[1]} == lee2021$'\t'0$'\t'preprint* ]]
  [[ ${lines[2]} == park2022$'\t'0$'\t'* ]]
  [[ ${lines[3]} == ruiz2021$'\t'0$'\t'* ]]
  [[ ${lines[4]} == wu2023$'\t'0$'\t'webpage* ]]
  [[ $output != *kim2018* ]]
}

@test "preprints matches a repository naming medRxiv, bioRxiv, SSRN or Research Square" {
  add_top N30 rep2022 journalArticle "Repository only" 2022 "" Rep '{"repository":"medRxiv"}'
  add_top N31 rep2023 journalArticle "Repository two" 2023 "" Rep '{"repository":"Research Square"}'
  finish_library
  run -0 --separate-stderr z preprints "$BATS_TEST_TMPDIR"
  [[ $output == *rep2022* && $output == *rep2023* ]]
}

@test "preprints counts the qmd files citing each key and ignores a longer key and other extensions" {
  mkdir -p "$BATS_TEST_TMPDIR/docs/sub"
  printf 'See @lee2021 and [@lee2021, p. 3].\n' >"$BATS_TEST_TMPDIR/docs/a.qmd"
  printf 'Nested -@lee2021.\n' >"$BATS_TEST_TMPDIR/docs/sub/b.qmd"
  printf 'Only @lee2021a here.\n' >"$BATS_TEST_TMPDIR/docs/c.qmd"
  printf '@lee2021 in markdown.\n' >"$BATS_TEST_TMPDIR/docs/d.md"
  printf '@park2022\n' >"$BATS_TEST_TMPDIR/docs/e.qmd"
  run -0 --separate-stderr z preprints "$BATS_TEST_TMPDIR/docs"
  [[ $output == *$'lee2021\t2\t'* ]]
  [[ $output == *$'park2022\t1\t'* ]]
  [[ $output == *$'chan2020\t0\t'* ]]
}

@test "preprints defaults to the current directory" {
  mkdir -p "$BATS_TEST_TMPDIR/cwd"
  printf '@wu2023\n' >"$BATS_TEST_TMPDIR/cwd/x.qmd"
  cd "$BATS_TEST_TMPDIR/cwd"
  run -0 --separate-stderr z preprints
  [[ $output == *$'wu2023\t1\t'* ]]
}

@test "preprints exits 2 on a directory that does not exist" {
  run -2 --separate-stderr z preprints "$BATS_TEST_TMPDIR/absent"
}

@test "preprints keeps a notice with no citation key in the right columns" {
  add_top N32 "" preprint "Keyless preprint" 2024 10.48550/arXiv.2400.00001 Keyless
  finish_library
  run -0 --separate-stderr z preprints "$BATS_TEST_TMPDIR"
  [ "${lines[0]}" = $'\t0\tpreprint\t10.48550/arXiv.2400.00001\tKeyless preprint' ]
}

@test "cache prints the path and exits 0 when the DOI opens the cache" {
  run -0 --separate-stderr z cache smith2020
  [ "$output" = "$STORE/S1/.zotero-ft-cache" ]
  [[ $stderr == "zotero-skill.sh: match doi=1 "* ]]
  [[ $stderr == *"attachment=S1" ]]
}

@test "cache matches on surname, year and title when the DOI is not in the cache" {
  run -0 --separate-stderr z cache lee2021
  [ "$stderr" = "zotero-skill.sh: match doi=0 surname=1 year=1 title=5/5 attachment=L1" ]
}

@test "cache exits 1 and still prints the path when the PDF is another article" {
  run -1 --separate-stderr z cache jones2019
  [ "$output" = "$STORE/J1/.zotero-ft-cache" ]
  [ "$stderr" = "zotero-skill.sh: no-match doi=0 surname=0 year=0 title=0/5 attachment=J1" ]
}

@test "cache exits 4 on an unknown citation key" {
  run -4 --separate-stderr z cache nobody1999
  [ -z "$output" ]
  [[ $stderr == *"nobody1999"* ]]
}

@test "cache exits 5 on a notice with no PDF, with a linked PDF only, and with no cache file" {
  run -5 --separate-stderr z cache nopdf2018
  [[ $stderr == *"no PDF attachment"* ]]
  run -5 --separate-stderr z cache linked2017
  [[ $stderr == *"only linked"* ]]
  run -5 --separate-stderr z cache nocache2016
  [[ $stderr == *"no .zotero-ft-cache"* ]]
}

@test "cache reads the cache of a linked_file PDF, which Zotero stores under the attachment key" {
  add_top N51 linkedfile2020 journalArticle "x" "" 10.9999/linkedfile ""
  attach N51 LF1 linked_file
  cache_text LF1 "see 10.9999/linkedfile"
  finish_library
  run -0 --separate-stderr z cache linkedfile2020
  [ "$output" = "$STORE/LF1/.zotero-ft-cache" ]
}

@test "cache picks the attachment that matches and reports the other candidate" {
  run -0 --separate-stderr z cache multi2020
  [ "$output" = "$STORE/M2/.zotero-ft-cache" ]
  [[ $stderr == *"other candidate: no-match"*"attachment=M1"* ]]
}

@test "cache finds the PDF of a trashed notice, whose children the API refuses" {
  add_trashed_parent T1 gone2015 "A trashed article about estimators" true
  attach T1 TA1 imported_file trash
  cache_text TA1 "A trashed article about estimators
Pat Gone 2015"
  finish_library
  run -0 --separate-stderr z cache gone2015
  [ "$output" = "$STORE/TA1/.zotero-ft-cache" ]
  [[ $stderr == *"match"*"trashed attachment=TA1" ]]
}

@test "cache finds a trashed PDF attachment of a live notice and flags it" {
  add_top N40 live2014 journalArticle "Estimating survival from registry data" 2014 "" Live
  attach N40 TB1 imported_file trash
  cache_text TB1 "Estimating survival from registry data
Lou Live 2014"
  finish_library
  run -0 --separate-stderr z cache live2014
  [ "$output" = "$STORE/TB1/.zotero-ft-cache" ]
  [[ $stderr == *"trashed"* ]]
}

@test "cache folds accents on both sides before comparing" {
  add_top N41 celik2022 journalArticle "Évaluation médicale des modèles prédictifs" 2022 "" "Çelik"
  attach N41 AC1
  cache_text AC1 "EVALUATION MEDICALE DES MODELES PREDICTIFS
CELIK 2022"
  finish_library
  run -0 --separate-stderr z cache celik2022
  [[ $stderr == *"surname=1 year=1 title=4/4"* ]]
}

@test "cache matches a surname as a whole word only" {
  add_top N42 li2020 journalArticle "x" 2020 "" Li
  attach N42 LI1
  cache_text LI1 "relieved and delighted, 2021"
  finish_library
  run -1 --separate-stderr z cache li2020
  [[ $stderr == *"surname=0 year=0"* ]]
}

@test "cache matches a year as a whole number only" {
  add_top N43 yr2020 journalArticle "x" 2020 "" Yr
  attach N43 YR1
  cache_text YR1 "Yr 12020 and 20201"
  finish_library
  run -1 --separate-stderr z cache yr2020
  [[ $stderr == *"surname=1 year=0"* ]]
}

@test "cache drops a surname that transliterates to question marks instead of matching any" {
  add_top N50 wang2020 journalArticle "x" 2020 "" "王"
  attach N50 WG1
  cache_text WG1 "Cohort study (?) of 2020 outcomes"
  finish_library
  run -1 --separate-stderr z cache wang2020
  [[ $stderr == "zotero-skill.sh: unscorable "* ]]
}

@test "cache counts a singular for a plural in the title words" {
  add_top N44 plural2020 journalArticle "Hierarchical estimators of treatment effects" 2020 "" Plural
  attach N44 PL1
  cache_text PL1 "Hierarchical estimator of treatment effect, a note. Plural 2020"
  finish_library
  run -0 --separate-stderr z cache plural2020
  [[ $stderr == *"title=4/4"* ]]
}

@test "cache reports unscorable, with exit 1, when the notice offers nothing to compare" {
  add_top N45 bare2000 journalArticle "Note 12" "" "" ""
  attach N45 BA1
  cache_text BA1 "Anything at all"
  finish_library
  run -1 --separate-stderr z cache bare2000
  [[ $stderr == "zotero-skill.sh: unscorable "* ]]
}

@test "cache with a DOI absent from the head is no-match, not unscorable" {
  add_top N46 doionly2000 journalArticle "x" "" 10.9999/abc ""
  attach N46 DO1
  cache_text DO1 "Nothing relevant here"
  finish_library
  run -1 --separate-stderr z cache doionly2000
  [[ $stderr == "zotero-skill.sh: no-match "* ]]
}

@test "the guard reads the first 5000 bytes and not beyond" {
  add_top N47 deep2000 journalArticle "x" "" 10.9999/deep ""
  attach N47 DP1
  mkdir -p "$STORE/DP1"
  {
    head -c 5200 /dev/zero | tr '\0' 'x'
    printf '\n10.9999/deep\n'
  } >"$STORE/DP1/.zotero-ft-cache"
  add_top N48 near2000 journalArticle "x" "" 10.9999/near ""
  attach N48 NR1
  mkdir -p "$STORE/NR1"
  {
    head -c 3000 /dev/zero | tr '\0' 'x'
    printf '\n10.9999/near\n'
  } >"$STORE/NR1/.zotero-ft-cache"
  finish_library
  run -1 --separate-stderr z cache deep2000
  run -0 --separate-stderr z cache near2000
}

@test "cache survives a backslash and a multibyte character cut by the head" {
  add_top N49 cut2000 journalArticle "x" "" 10.9999/cut ""
  attach N49 CU1
  mkdir -p "$STORE/CU1"
  {
    printf '%s\n' "10.9999/cut \\n \\\\"
    head -c 4981 /dev/zero | tr '\0' 'x'
    printf 'éééé\n'
  } >"$STORE/CU1/.zotero-ft-cache"
  finish_library
  run -0 --separate-stderr z cache cut2000
  [[ $stderr == "zotero-skill.sh: match "* ]]
}

@test "grep prints each matching notice once, with its title, as whole words, any case" {
  cache_text S1 "Quantifying hospital readmission with Propensity methods. 10.1000/xyz123 Smith 2020"
  cache_text M2 "propensity again and propensity twice"
  cache_text M1 "A propensity checklist"
  cache_text J1 "propensityscore is not a whole word here"
  run -0 --separate-stderr z grep propensity
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = $'multi2020\tRealistic evaluation of survival estimators' ]
  [ "${lines[1]}" = $'smith2020\tQuantifying hospital readmission patterns with propensity methods' ]
}

@test "grep resolves an attachment of a trashed notice through the trash" {
  add_trashed_parent T1 gone2015 "A trashed article" true
  attach T1 TA1 imported_file trash
  cache_text TA1 "the word zebrafish occurs here"
  finish_library
  run -0 --separate-stderr z grep zebrafish
  [ "$output" = $'gone2015\tA trashed article' ]
}

@test "grep reports a cache that belongs to no notice on stderr and exits 1 when nothing else matched" {
  cache_text ORPHAN "the word quokka occurs here"
  run -1 --separate-stderr z grep quokka
  [ -z "$output" ]
  [[ $stderr == *"1 matching cache(s) belong to no item"*ORPHAN* ]]
}

@test "grep keeps the matched notices and still reports an orphan" {
  cache_text ORPHAN "the word quokka occurs here"
  cache_text S1 "quokka in Smith 2020"
  run -0 --separate-stderr z grep quokka
  [ "$output" = $'smith2020\tQuantifying hospital readmission patterns with propensity methods' ]
  [[ $stderr == *ORPHAN* ]]
}

@test "grep exits 1 with no output when no cache matches" {
  run -1 --separate-stderr z grep zzzqqq
  [ -z "$output" ]
}

@test "grep exits 2 on a term rg rejects, and 6 when the storage directory is absent" {
  run -2 --separate-stderr z grep 'a('
  [[ $stderr == *"rg rejected the term"* ]]
  rm -rf "$STORE"
  run -6 --separate-stderr z grep anything
  [[ $stderr == *"no storage directory"* ]]
}

@test "grep ignores a file that is not a full-text cache" {
  printf 'quokka\n' >"$STORE/S1/notes.txt"
  run -1 --separate-stderr z grep quokka
}

@test "live API: the fields the script reads exist, and keys agrees with Total-Results" {
  local api=${ZOTERO_API:-http://localhost:23119/api/users/0} code total field
  code=$(curl -s -m 3 -o /dev/null -w '%{http_code}' "$api/items?limit=1") || true
  if [ "$code" = 000 ]; then skip "Zotero API does not answer at $api"; fi
  [ "$code" = 200 ]
  curl -s -m 20 "$api/items/top?limit=500" >"$BATS_TEST_TMPDIR/top.json"
  for field in citationKey itemType DOI url repository title date creators; do
    jq -e --arg f "$field" 'any(.[]; .data | has($f))' "$BATS_TEST_TMPDIR/top.json" >/dev/null || {
      echo "no notice of the live library carries data.$field" >&2
      return 1
    }
  done
  jq -e 'any(.[].data.creators[]?; has("lastName") and has("creatorType"))' "$BATS_TEST_TMPDIR/top.json" >/dev/null
  curl -s -m 20 "$api/items?itemType=attachment&limit=500" >"$BATS_TEST_TMPDIR/att.json"
  for field in parentItem contentType linkMode filename; do
    jq -e --arg f "$field" 'any(.[]; .data | has($f))' "$BATS_TEST_TMPDIR/att.json" >/dev/null || {
      echo "no attachment of the live library carries data.$field" >&2
      return 1
    }
  done
  jq -e 'any(.[]; .data.linkMode == "imported_file" or .data.linkMode == "imported_url")' "$BATS_TEST_TMPDIR/att.json" >/dev/null
  total=$(curl -s -m 3 -D - -o /dev/null "$api/items/top?limit=1" | tr -d '\r' | awk -F': ' 'tolower($1) == "total-results" { print $2 }')
  [[ $total =~ ^[0-9]+$ ]]
  run -0 --separate-stderr bash "$SCRIPT" keys
  [ "${#lines[@]}" -eq "$total" ]
  curl -s -m 20 "$api/items/trash?limit=500" >"$BATS_TEST_TMPDIR/trash.json"
  jq -e 'type == "array"' "$BATS_TEST_TMPDIR/trash.json" >/dev/null
  if [ "$(jq length "$BATS_TEST_TMPDIR/trash.json")" -gt 0 ]; then
    jq -e 'any(.[]; .data | has("deleted"))' "$BATS_TEST_TMPDIR/trash.json" >/dev/null
  fi
}

@test "live API: start pages the notices and cache resolves a notice with a stored PDF" {
  local api=${ZOTERO_API:-http://localhost:23119/api/users/0} code first second parent key
  code=$(curl -s -m 3 -o /dev/null -w '%{http_code}' "$api/items?limit=1") || true
  if [ "$code" = 000 ]; then skip "Zotero API does not answer at $api"; fi
  first=$(curl -s -m 10 "$api/items/top?limit=1&start=0" | jq -r '.[0].key')
  second=$(curl -s -m 10 "$api/items/top?limit=1&start=1" | jq -r '.[0].key')
  [ -n "$first" ] && [ -n "$second" ] && [ "$first" != "$second" ]
  parent=$(curl -s -m 20 "$api/items?itemType=attachment&limit=500" |
    jq -r '[.[] | select(.data.contentType == "application/pdf" and .data.linkMode == "imported_file")][0].data.parentItem')
  key=$(curl -s -m 10 "$api/items/$parent" | jq -r '.data.citationKey // empty')
  [ -n "$key" ]
  run --separate-stderr bash "$SCRIPT" cache "$key"
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ] || [ "$status" -eq 5 ]
  [ "$status" -eq 5 ] || [ -f "$output" ]
}
