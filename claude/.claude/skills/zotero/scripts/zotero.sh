#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C.UTF-8

API=${ZOTERO_API:-http://localhost:23119/api/users/0}
API=${API%/}
STORAGE=${ZOTERO_STORAGE:-$HOME/Zotero/storage}
PAGE=500
HEAD_BYTES=5000
CACHE_NAME=.zotero-ft-cache

work=
trap '[[ -z $work ]] || rm -rf "$work"' EXIT

usage() {
  cat <<'EOF'
usage: zotero.sh <subcommand> [argument]

  keys               every top-level notice: citationKey, itemType, DOI, title (TSV)
  cache <key>        path of the full-text cache of the notice's PDF, with an identity guard
  grep <term>        notices whose full-text cache matches <term> (rg -i -w, regex): citationKey, title
  preprints [dir]    preprint notices: citationKey, number of .qmd under dir citing it, itemType, DOI, title
  trash              trashed parent notices: citationKey, item key, itemType, deleted flag, title

exit status: 0 done or guard match, 1 no match, 2 usage, 3 API down,
             4 unknown citation key, 5 no PDF or no cache, 6 other failure
environment: ZOTERO_API, ZOTERO_STORAGE
EOF
}

die() {
  local code=$1
  shift
  printf 'zotero.sh: %s\n' "$*" >&2
  exit "$code"
}

setup() {
  local tool
  for tool in curl jq rg iconv awk; do
    command -v "$tool" >/dev/null || die 6 "$tool is not installed"
  done
  work=$(mktemp -d) || die 6 "cannot create a temporary directory"
}

http_get() {
  local code
  code=$(curl -s --connect-timeout 3 -m 30 -o "$2" -D "$3" -w '%{http_code}' "$1") || code=000
  printf '%s' "$code"
}

fetch_all() {
  local path=$1 out=$2 soft=${3-} sep='?' start=0 code total n
  [[ $path == *\?* ]] && sep='&'
  printf '[]' >"$out"
  while :; do
    : >"$work/hdr"
    code=$(http_get "$API/${path}${sep}limit=$PAGE&start=$start" "$work/body" "$work/hdr")
    case $code in
    200) ;;
    000) die 3 "the Zotero API does not answer at $API (Zotero closed?)" ;;
    404)
      if [[ -n $soft ]]; then return 0; fi
      die 6 "HTTP 404 on $path"
      ;;
    *) die 6 "HTTP $code on $path" ;;
    esac
    n=$(jq 'length' "$work/body" 2>/dev/null) || die 6 "unreadable JSON from $path"
    jq -s 'add' "$out" "$work/body" >"$out.next" && mv "$out.next" "$out"
    start=$((start + n))
    ((n > 0)) || break
    total=$(awk -F': ' 'tolower($1) == "total-results" { gsub(/\r/, "", $2); print $2 }' "$work/hdr")
    [[ $total =~ ^[0-9]+$ ]] || die 6 "no Total-Results header on $path"
    ((start < total)) || break
  done
}

norm() {
  iconv -f UTF-8 -t ASCII//TRANSLIT -c 2>/dev/null | tr '[:upper:]' '[:lower:]'
}

# shellcheck disable=SC2016
GUARD_AWK='
function word(h, w, cls,   off, rest, p, b, a) {
  if (w == "") return 0
  off = 0
  rest = h
  while ((p = index(rest, w)) > 0) {
    b = (off + p == 1) ? "" : substr(h, off + p - 1, 1)
    a = substr(h, off + p + length(w), 1)
    if (b !~ cls && a !~ cls) return 1
    off += p
    rest = substr(h, off + 1)
  }
  return 0
}
{ h = h $0 " " }
END {
  doi = ENVIRON["G_DOI"]; sur = ENVIRON["G_SUR"]; yr = ENVIRON["G_YR"]; title = ENVIRON["G_TITLE"]
  fd = (doi != "" && index(h, doi) > 0) ? 1 : 0
  fs = word(h, sur, "[a-z]")
  fy = word(h, yr, "[0-9]")
  n = split(title, parts, /[^a-z]+/)
  nt = 0
  for (i = 1; i <= n; i++) {
    w = parts[i]
    if (length(w) >= 6 && !(w in seen)) { seen[w] = 1; tk[++nt] = w }
  }
  found = 0
  for (i = 1; i <= nt; i++) {
    w = tk[i]
    sub(/s$/, "", w)
    if (index(h, w) > 0) found++
  }
  tt = (nt >= 2 && found / nt >= 0.8) ? 1 : 0
  ev = (sur != "") + (yr != "") + (nt >= 2)
  if (fd || fs + fy + tt >= 2) v = "match"
  else if (doi == "" && ev < 2) v = "unscorable"
  else v = "no-match"
  printf "%s doi=%d surname=%d year=%d title=%d/%d\n", v, fd, fs, fy, found, nt
}'

guard() {
  local cache=$1 doi=$2 sur=$3 yr=$4 title=$5
  head -c "$HEAD_BYTES" "$cache" 2>/dev/null | norm | tr -s '[:space:]' ' ' |
    G_DOI=$doi G_SUR=$sur G_YR=$yr G_TITLE=$title awk "$GUARD_AWK"
}

cmd_keys() {
  fetch_all items/top "$work/top.json"
  jq -r 'sort_by(.data.citationKey // "") | .[] | .data
    | [(.citationKey // ""), .itemType, (.DOI // ""), (.title // "")]
    | map(gsub("[\\t\\n\\r]+"; " ")) | @tsv' "$work/top.json"
}

cmd_trash() {
  fetch_all items/trash "$work/trash.json"
  jq -r '.[] | select(.data.itemType | IN("attachment", "note", "annotation") | not)
    | .data | [(.citationKey // ""), .key, .itemType, ((.deleted // false) | tostring), (.title // "")]
    | map(gsub("[\\t\\n\\r]+"; " ")) | @tsv' "$work/trash.json"
}

cmd_preprints() {
  local dir=${1:-.} key re count
  [[ -d $dir ]] || die 2 "$dir is not a directory"
  fetch_all items/top "$work/top.json"
  jq -r 'map(.data) | sort_by(.citationKey // "") | .[]
    | select(
        .itemType == "preprint"
        or ((.DOI // "") | test("^10\\.(48550|1101|2139|21203)/"))
        or ((.url // "") | test("(arxiv|medrxiv|biorxiv)\\.org|ssrn\\.com|researchsquare\\.com"; "i"))
        or ((.repository // "") | test("arxiv|medrxiv|biorxiv|ssrn|research ?square"; "i"))
      )
    | [(.citationKey // ""), .itemType, (.DOI // ""), (.title // "")]
    | map(gsub("[\\t\\n\\r\u001f]+"; " ")) | join("\u001f")' "$work/top.json" |
    while IFS=$'\x1f' read -r key rest; do
      rest=${rest//$'\x1f'/$'\t'}
      count=0
      if [[ -n $key ]]; then
        re="@$(printf '%s' "$key" | sed 's/[][(){}.*+?^$|\\]/\\&/g')([^A-Za-z0-9_]|\$)"
        count=$(rg -l --glob '*.qmd' -e "$re" "$dir" 2>/dev/null | wc -l)
      fi
      printf '%s\t%s\t%s\n' "$key" "$count" "$rest"
    done
}

cmd_grep() {
  local term=${1-} rc
  [[ -n $term ]] || die 2 "grep needs a term"
  [[ -d $STORAGE ]] || die 6 "no storage directory at $STORAGE"
  fetch_all items/top "$work/top.json"
  fetch_all items/trash "$work/trash.json"
  fetch_all 'items?itemType=attachment' "$work/att.json"
  rg -l -i -w --hidden -g "$CACHE_NAME" -e "$term" "$STORAGE" >"$work/hits" 2>"$work/rg.err"
  rc=$?
  ((rc == 2)) && die 2 "rg rejected the term: $(head -n 1 "$work/rg.err")"
  while IFS= read -r path; do
    path=${path%/*}
    printf '%s\n' "${path##*/}"
  done <"$work/hits" >"$work/hit-keys"
  jq -n -r --rawfile hits "$work/hit-keys" --slurpfile top "$work/top.json" \
    --slurpfile trash "$work/trash.json" --slurpfile att "$work/att.json" '
    ($top[0] + $trash[0] | map({(.key): .data}) | add // {}) as $items
    | ($att[0] + $trash[0] | map(select(.data.itemType == "attachment") | {(.key): .data.parentItem}) | add // {}) as $parent
    | $hits | split("\n") | map(select(length > 0)) | .[]
    | . as $a | ($parent[$a] // null) as $p
    | if $p != null and $items[$p] != null
      then "K\t\($items[$p].citationKey // "")\t\($items[$p].title // "" | gsub("[\\t\\n\\r]+"; " "))"
      else "O\t\($a)" end' >"$work/mapped"
  rg '^K\t' "$work/mapped" | cut -f2- | LC_ALL=C sort -u
  rc=${PIPESTATUS[0]}
  local orphans
  orphans=$(rg -c '^O\t' "$work/mapped" || true)
  [[ -z $orphans ]] || printf 'zotero.sh: %s matching cache(s) belong to no notice of the library: %s\n' "$orphans" \
    "$(rg '^O\t' "$work/mapped" | cut -f2 | paste -sd' ')" >&2
  return "$((rc == 0 ? 0 : 1))"
}

cmd_cache() {
  local key=${1-} ikey notice doi sur yr title att mode trashed f line i
  local chosen=0 linked=0 pdfs=0 paths=() lines=()
  [[ -n $key ]] || die 2 "cache needs a citation key"
  fetch_all items/top "$work/top.json"
  fetch_all items/trash "$work/trash.json"
  notice=$(jq -s -c --arg k "$key" 'add
    | map(select(.data.citationKey == $k and (.data.itemType | IN("attachment", "note", "annotation") | not)))
    | .[0] // empty' "$work/top.json" "$work/trash.json")
  [[ -n $notice ]] || die 4 "no notice carries the citation key $key"
  ikey=$(jq -r '.key' <<<"$notice")
  doi=$(jq -r '.data.DOI // "" | ascii_downcase' <<<"$notice" | norm)
  sur=$(jq -r '[.data.creators[]? | select(.creatorType == "author")][0].lastName // ([.data.creators[]?][0].lastName // "")' <<<"$notice" | norm)
  yr=$(jq -r '(.data.date // "") | capture("(?<y>[0-9]{4})").y // ""' <<<"$notice")
  title=$(jq -r '.data.title // ""' <<<"$notice" | norm)
  fetch_all "items/$ikey/children" "$work/children.json" soft
  jq -s -r --arg p "$ikey" '
    (.[1] | map(.key)) as $tk
    | (.[0] + .[1]) | unique_by(.key)
    | map(select(.data.parentItem == $p and .data.contentType == "application/pdf"))
    | .[]
    | ((.data.deleted // false) as $d | ($d == true or $d == 1) or ([.key] | inside($tk))) as $t
    | [.key, (.data.linkMode // "none"), ($t | tostring)] | @tsv' "$work/children.json" "$work/trash.json" >"$work/candidates"
  while IFS=$'\t' read -r att mode trashed; do
    pdfs=$((pdfs + 1))
    if [[ $mode != imported_file && $mode != imported_url ]]; then
      linked=$((linked + 1))
      continue
    fi
    f="$STORAGE/$att/$CACHE_NAME"
    if [[ ! -f $f ]]; then
      continue
    fi
    line=$(guard "$f" "$doi" "$sur" "$yr" "$title")
    [[ $trashed == true ]] && line="$line trashed"
    paths+=("$f")
    lines+=("$line attachment=$att")
  done <"$work/candidates"
  ((pdfs > 0)) || die 5 "$key has no PDF attachment"
  if ((${#paths[@]} == 0)); then
    ((linked == pdfs)) && die 5 "$key has only linked PDFs, with no local file or cache"
    die 5 "$key has a PDF attachment but no $CACHE_NAME under $STORAGE"
  fi
  for i in "${!lines[@]}"; do
    if [[ ${lines[i]} == match* ]]; then
      chosen=$i
      break
    fi
  done
  printf '%s\n' "${paths[chosen]}"
  printf 'zotero.sh: %s\n' "${lines[chosen]}" >&2
  for i in "${!lines[@]}"; do
    ((i == chosen)) || printf 'zotero.sh: other candidate: %s\n' "${lines[i]}" >&2
  done
  [[ ${lines[chosen]} == match* ]]
}

sub=${1-}
case $sub in
-h | --help | help)
  usage
  exit 0
  ;;
keys)
  setup
  cmd_keys
  exit
  ;;
trash)
  setup
  cmd_trash
  exit
  ;;
preprints)
  setup
  cmd_preprints "${2-}"
  exit
  ;;
grep)
  setup
  cmd_grep "${2-}"
  exit
  ;;
cache)
  setup
  cmd_cache "${2-}"
  exit
  ;;
*)
  usage >&2
  exit 2
  ;;
esac
