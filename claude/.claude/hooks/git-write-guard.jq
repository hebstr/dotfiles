def unquoted: gsub("\\\\(?<c>[\\s\\S])"; .c);

def double_quoted: gsub("\\\\(?<c>[$`\"\\\\\n])"; if .c == "\n" then "" else .c end);

def ansi_c:
  [scan("\\\\[\\s\\S]?|[^\\\\]+")]
  | map(
      if startswith("\\") then
        ({"\\t": "\t", "\\n": "\n", "\\r": "\r", "\\\\": "\\", "\\'": "'", "\\\"": "\"", "\\a": "\u0007", "\\b": "\b", "\\e": "\u001b", "\\E": "\u001b", "\\f": "\f", "\\v": "\u000b", "\\?": "?"}[.] // "\u001e")
      else . end
    )
  | {v: (add // ""), o: any(.[]; . == "\u001e")};

def part($top):
  if .Type == "Lit" then
    .Value as $v
    | if $top then
        {v: ($v | unquoted),
         f: ((if ($v | test("\\\\")) then "e" else "" end)
           + (if ($v | test("[*?\\[]")) then "g" else "" end)
           + (if ($v | test("\\{[^{}]*(,|\\.\\.)[^{}]*\\}")) then "b" else "" end))}
      else {v: ($v | double_quoted), f: ""} end
  elif .Type == "SglQuoted" then
    if .Dollar then (.Value | ansi_c) as $a | {v: $a.v, f: ("q" + (if $a.o then "o" else "" end))}
    else {v: .Value, f: "q"} end
  elif .Type == "DblQuoted" then
    [.Parts[]? | part(false)] | {v: (map(.v) | add // ""), f: ("q" + (map(.f) | add // ""))}
  elif .Type == "ExtGlob" then {v: "*", f: "g"}
  elif $top then {v: "$", f: "du"}
  else {v: "$", f: "d"} end;

def word: [.Parts[]? | part(true)] | {v: (map(.v) | add // ""), f: (map(.f) | add // "")};

def substs:
  if type == "object" then
    if .Type == "CmdSubst" or .Type == "ProcSubst" then . else (.[] | substs) end
  elif type == "array" then .[] | substs
  else empty end;

def stmt($pre):
  def nested: substs | (["S"], (.Stmts[]? | stmt([])), ["E"]);
  def call($pre; $r):
    (.Assigns // []) as $as
    | (.Args // []) as $args
    | ($as[] | (.Value, .Index, .Array) | nested),
      ($args[] | nested),
      (["C", ($as | length | tostring)]
        + [$as[] | .Name.Value]
        + [(($pre | length) + ($args | length)) | tostring]
        + [$pre[] | ("", .)]
        + [range(0; $args | length) as $k
          | $args[$k] as $w
          | ($w | word) as $i
          | (if any($r[]; .OpPos.Offset < $w.Pos.Offset and ($k == 0 or .OpPos.Offset > $args[$k - 1].End.Offset)) then "r" else "" end) as $rf
          | ($i.f + $rf), $i.v]);
  def decl:
    (.Args // []) as $args
    | ($args[] | nested),
      (["C", "0", (($args | length) + 1 | tostring), "", .Variant.Value]
        + [$args[]
          | if .Naked then (if .Value then (.Value | word) else {v: .Name.Value, f: ""} end)
            else ((.Value // {Parts: []}) | word) as $i | {v: ((.Name.Value // "") + "=" + $i.v), f: $i.f} end
          | .f, .v]);
  def branches: (.Cond[]? | stmt([])), (.Then[]? | stmt([])), (.Else | if . then branches else empty end);
  def structural:
    if .Type == "BinaryCmd" then
      if .Op == 12 or .Op == 13 then ["S"], (.X | stmt([])), ["E"], ["S"], (.Y | stmt([])), ["E"]
      else (.X | stmt([])), (.Y | stmt([])) end
    elif .Type == "Subshell" then ["S"], (.Stmts[]? | stmt([])), ["E"]
    elif .Type == "Block" then .Stmts[]? | stmt([])
    elif .Type == "IfClause" then ["K", "if"], branches
    elif .Type == "WhileClause" then ["K", "while"], (.Cond[]? | stmt([])), (.Do[]? | stmt([]))
    elif .Type == "ForClause" then ["K", "for"], (.Loop | nested), (.Do[]? | stmt([]))
    elif .Type == "CaseClause" then ["K", "case"], (.Word | nested), (.Items[]? | (.Patterns | nested), (.Stmts[]? | stmt([])))
    elif .Type == "FuncDecl" then ["K", "a function"], ["S"], (.Body | stmt([])), ["E"]
    elif .Type == "TimeClause" then (if .Stmt then (.Stmt | stmt(["time"])) else ["K", "time"] end)
    elif .Type == "CoprocClause" then ["S"], (.Stmt | stmt(["coproc"])), ["E"]
    elif .Type == "DeclClause" then decl
    elif .Type == "TestClause" then ["K", "[["], nested
    elif .Type == "ArithmCmd" then ["K", "(("], nested
    elif .Type == "LetClause" then ["K", "let"], nested
    else ["K", .Type], nested end;
  (.Redirs // []) as $r
  | (if any($r[]; .Op | IN(54, 55, 57, 59, 60, 64, 65)) then ["R"] else empty end),
    ($r[] | (.Word, .Hdoc) | nested),
    ($r[]
      | select(.Op | IN(61, 62, 63))
      | if .Hdoc then
          (if all(.Hdoc.Parts[]?; .Type == "Lit")
           then ["H", "", (.Hdoc.Parts | map(.Value) | add // "")]
           else ["H", "d", ""] end)
        else (.Word | word) as $h | ["H", $h.f, $h.v] end),
    (if .Background then ["S"] else empty end),
    (.Cmd
      | if . == null then empty
        elif .Type == "CallExpr" then call($pre; $r)
        else (if ($pre | length) > 0 then ["K", $pre[0]] else empty end), structural end),
    (if .Background then ["E"] else empty end);

(if any(.. | objects | select(has("Hash")) | .Text; test("\\\\\n$")) then ["X"] else [] end)
+ [.Stmts[]? | stmt([])]
| flatten | map(. + "\u0000") | add // ""
