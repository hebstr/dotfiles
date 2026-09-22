#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

SCRIPT="${CLEAN_HTML_ID:-$BATS_TEST_DIRNAME/../../git/.config/git/clean-html-id}"

_gt_table() {
  printf '<div id="%s" style="padding-left:0px;">\n<style>#%s table { color: red; }\n#%s thead { color: blue; }</style>\n</div>\n' "$1" "$1" "$1"
}

_widget() {
  printf '<div class="reactable html-widget" id="htmlwidget-%s"></div>\n<script type="application/json" data-for="htmlwidget-%s">{}</script>\n<script type="application/htmlwidget-sizing" data-for="htmlwidget-%s">{}</script>\n' "$1" "$1" "$1"
}

@test "the gitconfig driver points at this script inside the git package" {
  run -0 git config -f "$BATS_TEST_DIRNAME/../../git/.gitconfig" --get filter.html-id.clean
  # shellcheck disable=SC2088
  [ "$output" = '~/.config/git/clean-html-id' ]
  [ -x "$BATS_TEST_DIRNAME/../../git/.config/git/clean-html-id" ]
}

@test "gt ids are numbered in order of appearance on the div and every selector" {
  {
    _gt_table xjrgvihqto
    _gt_table abcdefghij
  } >"$BATS_TEST_TMPDIR/in.html"
  run -0 --separate-stderr "$SCRIPT" <"$BATS_TEST_TMPDIR/in.html"
  [ -z "$stderr" ]
  [ "$output" = "$({
    _gt_table gt1
    _gt_table gt2
  })" ]
}

@test "htmlwidget ids are numbered on the container and every data-for" {
  {
    _widget 48b3cdc65c5f381848a6
    _widget 0123456789abcdef0123
  } >"$BATS_TEST_TMPDIR/in.html"
  run -0 --separate-stderr "$SCRIPT" <"$BATS_TEST_TMPDIR/in.html"
  [ -z "$stderr" ]
  [ "$output" = "$({
    _widget wdg1
    _widget wdg2
  })" ]
}

@test "gt and htmlwidget ids keep separate counters when interleaved" {
  {
    _widget 48b3cdc65c5f381848a6
    _gt_table xjrgvihqto
    _widget 0123456789abcdef0123
  } >"$BATS_TEST_TMPDIR/in.html"
  run -0 --separate-stderr "$SCRIPT" <"$BATS_TEST_TMPDIR/in.html"
  [ -z "$stderr" ]
  [ "$output" = "$({
    _widget wdg1
    _gt_table gt1
    _widget wdg2
  })" ]
}

@test "a ten-letter id outside a gt div is left untouched" {
  {
    printf '<section id="discussion">\n'
    _gt_table xjrgvihqto
  } >"$BATS_TEST_TMPDIR/in.html"
  run -0 --separate-stderr "$SCRIPT" <"$BATS_TEST_TMPDIR/in.html"
  [ -z "$stderr" ]
  [ "$output" = "$({
    printf '<section id="discussion">\n'
    _gt_table gt1
  })" ]
}

@test "a ten-letter div id without the gt padding style is left untouched" {
  {
    printf '<div id="navigation" class="sidebar"></div>\n<style>#navigation { color: red; }</style>\n'
    _gt_table xjrgvihqto
  } >"$BATS_TEST_TMPDIR/in.html"
  run -0 --separate-stderr "$SCRIPT" <"$BATS_TEST_TMPDIR/in.html"
  [ -z "$stderr" ]
  [ "$output" = "$({
    printf '<div id="navigation" class="sidebar"></div>\n<style>#navigation { color: red; }</style>\n'
    _gt_table gt1
  })" ]
}

@test "an htmlwidget id shorter than sixteen hex characters is left untouched" {
  _widget 0123456789abcde >"$BATS_TEST_TMPDIR/in.html"
  run -0 --separate-stderr "$SCRIPT" <"$BATS_TEST_TMPDIR/in.html"
  [ -z "$stderr" ]
  [ "$output" = "$(_widget 0123456789abcde)" ]
}

@test "a second pass changes nothing" {
  {
    _gt_table xjrgvihqto
    _widget 48b3cdc65c5f381848a6
  } >"$BATS_TEST_TMPDIR/in.html"
  "$SCRIPT" <"$BATS_TEST_TMPDIR/in.html" >"$BATS_TEST_TMPDIR/once.html"
  grep -q 'id="gt1"' "$BATS_TEST_TMPDIR/once.html"
  grep -q 'htmlwidget-wdg1' "$BATS_TEST_TMPDIR/once.html"
  "$SCRIPT" <"$BATS_TEST_TMPDIR/once.html" >"$BATS_TEST_TMPDIR/twice.html"
  cmp "$BATS_TEST_TMPDIR/once.html" "$BATS_TEST_TMPDIR/twice.html"
}

@test "html without generated ids passes through byte for byte" {
  printf '<p id="intro">Texte accentu\303\251</p>\r\n<p>\351</p>\n' >"$BATS_TEST_TMPDIR/in.html"
  "$SCRIPT" <"$BATS_TEST_TMPDIR/in.html" >"$BATS_TEST_TMPDIR/out.html" 2>"$BATS_TEST_TMPDIR/err"
  cmp "$BATS_TEST_TMPDIR/in.html" "$BATS_TEST_TMPDIR/out.html"
  [ ! -s "$BATS_TEST_TMPDIR/err" ]
}

@test "empty input yields empty output and no warning" {
  run -0 --separate-stderr "$SCRIPT" </dev/null
  [ -z "$output" ]
  [ -z "$stderr" ]
}
