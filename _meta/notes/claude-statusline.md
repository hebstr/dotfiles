# Claude Code statusline

`claude/.claude/statusline.sh` renders `Context N% | 5h: N% (reset) | 7d: N% (reset)` from the JSON the CLI pipes to the `statusLine` command declared in `claude/.claude/settings.json`.
It has no dependency beyond `jq` and coreutils, and it must never write to stderr or exit non-zero: the CLI renders whatever lands on stdout, so a failure shows up as a mangled line rather than an error.
`_meta/tests/statusline.bats` pins it, and `prek.toml`'s `bats-tests` hook lists the script's path explicitly so a change to it replays that suite.

## The payload

The CLI builds `rate_limits` by spreading each window only when its utilization object exists:

```js
let At = {...wt.five_hour && {five_hour: {used_percentage: ..., resets_at: ...}},
          ...wt.seven_day && {seven_day: {...}},
          ...gateway && wt.overage && {spend_limit: {...}}};
...(At.five_hour || At.seven_day || At.spend_limit) && {rate_limits: At}
```

Three consequences the script has to absorb. A window that has reported nothing is an **absent key**, not a null value, so `.rate_limits.five_hour.used_percentage` and a literal `null` are indistinguishable downstream and both have to mean "unavailable".
`rate_limits` itself disappears when no window at all is known, which happens on the first renders of a session before any API response has carried utilization.
`spend_limit` is a third window, gateway-only, that the statusline does not display; it must not shift or colour anything.

`resets_at` is a Unix epoch as a number. The script also accepts an ISO 8601 string through `fromdateiso8601`, so a schema change in that direction never yields a wrong countdown.
A plain `…Z` string gives a correct one; a string with fractional seconds or a numeric offset (`.123Z`, `+00:00`) fails the parse (measured on jq 1.7, 2026-11-14) and the segment shows its percentage with no countdown.
Those two shapes stay unhandled: no payload carries a string today, and a missing countdown is the safe outcome.

The context percentage is read from `context_window.used_percentage` and never recomputed from the token counts.
The CLI's own `Ajr()` sums `input_tokens`, `cache_creation_input_tokens` and `cache_read_input_tokens`, divides by `context_window_size`, then rounds and clamps to `[0, 100]`; `Abt()` publishes the result as that field and the same sum as `total_input_tokens`.
The script summed those three fields itself until 2026-11-13 and rendered the quotient through `awk printf "%d"`, which truncates where the CLI rounds and never clamps: 139200 of 200000 tokens displayed `Context 69%` against the CLI's 70, 169800 displayed 84 against 85, and an over-full window displayed `Context 125%`.
The colour thresholds (70 yellow, 85 red) therefore tripped one point late.
The field is `null` on a session that has sent nothing, which `as_pct` turns into the empty string and the binding turns into `0`, so a fresh session still reads `Context 0%`.

## Why `5h: --` shows on Ultra (diagnosed 2026-11-14)

A verified Ultra account (the former Max 20x) has no five-hour limit, per claude.com/pricing ("No 5-hour limit for verified accounts"), so the payload carries no `five_hour` key and the segment reads `--`.
By the user's account, they moved to Ultra on 2026-11-11, the date the key disappeared; `~/.cache/claude-statusline/last.json`, a verbatim copy of the live `rate_limits`, held only `seven_day`.
The causal link between the plan and the payload is an inference: no Anthropic text states that the CLI omits `five_hour` for such accounts.
The Claude Code statusline reference only says each window may be independently absent.

Decision: the script is left unchanged.
`--` is the honest rendering of a window that does not exist, and a downgrade to Max brings `five_hour` back with no edit.
Dropping the segment would be warranted only if the account stays on Ultra for good.

## The field-shift defect (fixed 2026-11-13)

Symptom: `7d: 1795078800%`, a raw epoch printed as a percentage, while `5h` showed `--`.
It appeared when the five-hour window stopped being reported, around 2026-11-11.

The script read six `@tsv` fields with `IFS="$(printf '\t')" read -r a b c d e f`.
**A tab is an IFS whitespace character**, so bash collapses runs of tabs into a single delimiter instead of treating each as one field boundary.
With `five_hour` absent, fields 3 and 4 came out as `null` and empty, the empty one vanished, and every later field moved up one position: `seven_day.resets_at` landed in the slot the seven-day percentage should have occupied.
Setting `IFS` to a tab does not opt out of that collapsing; only a non-whitespace delimiter would, and the values themselves cannot guarantee one.

The fix drops the tab split. jq emits one value per line and `mapfile -t` reads them positionally, which preserves an empty field.
jq also normalizes at the source: `as_pct` rounds a number and yields an empty string for anything else, `as_epoch` yields an integer epoch or an empty string.
Downstream, "unavailable" is exactly the empty string; the `"null"` sentinel the old code compared against is gone.

`format_reset` rejects its argument unless it is all digits. It used to strip non-digits with `tr -dc '0-9'`, which turned an ISO timestamp into a 14-digit integer and would have produced a countdown in the millions of days.

## Cache semantics

`~/.cache/claude-statusline/last.json` exists to carry the rate-limit segments through the renders where `rate_limits` is absent from the payload. It holds `{rate_limits: ...}` verbatim and is read only while its mtime is under `CACHE_MAX_AGE` (6 h).

**A live payload carrying any window is authoritative, and the cache is not consulted at all.**
Per-window fallback was rejected: a window the server has stopped reporting would be re-read from the cache and re-persisted on every render, so a stale value would display forever with no way to age out. Whole-file replacement keeps the mtime an honest freshness signal for everything inside.
The write is therefore a replace, not a merge, and it fires whenever either window is live, which is why a payload carrying only `seven_day` still refreshes the file. The previous gate keyed on the five-hour window alone and had frozen the cache from 2026-11-11 onward.

The write goes through `last.json.<pid>`, a name no other render shares.
The cache path is common to every Claude session on the machine, and the fixed `last.json.tmp` it used until 2026-11-14 let two overlapping renders promote a half-written file: the review measured 1 unparseable cache in 320 launches (8 concurrent renders, 40 rounds), and the next payload without `rate_limits` then showed `5h: --` and `7d: --` until a live render rewrote it.
A failed write removes its own temporary file rather than leaving one beside the cache; a render killed between the write and the `mv` can leave a `last.json.<pid>` behind, a window of a few milliseconds that nothing sweeps.

`cache_file_mtime` reads the mtime with GNU `stat -c %Y` alone.
The BSD `stat -f %m` fallback it carried until 2026-11-13 was unreachable, the GNU form failing only on a missing file and the caller already guarding on `[ -f ]`, and harmful if ever reached: GNU reads `%m` as a file operand rather than a format, so it would have put a multi-line filesystem report on stdout in place of an epoch.

`unless_reset` drops a cached percentage whose `resets_at` has passed, because the retention window (6 h) outlives the five-hour window it caches: a 4 % read five hours ago describes a window that has since rolled over to near zero, and `--` is the honest answer. A cached window reporting no `resets_at` is kept, there being nothing to decide on. Borrowed from ccstatusline, whose v2.2.32 notes list the same rule as "stale usage fallback drops windows that have reset".

## ccstatusline (evaluated 2026-11-13, not adopted)

`sirmalloc/ccstatusline`, MIT, TypeScript, 13.6k stars, the npm package behind most Claude Code statusline screenshots. Its feature set is an order of magnitude wider: powerline rendering, a React/Ink configuration TUI, multi-line layouts, per-widget colours, git and JJ widgets, block timers, usage forecasts, cost tracking and spend-limit widgets.

Not adopted. It spawns a Node or Bun process on every repaint, queries an Anthropic usage API with its own backoff, credential lookup and per-account cache, and keeps its configuration in `~/.config/ccstatusline/settings.json`, outside the stow tree. The script it would replace is one `bash` plus two `jq` calls per render (the live parse, then either the cache read or the cache write, which are exclusive branches), has no network surface, no credential access and no state beyond a cache of a few hundred bytes, and is pinned by `_meta/tests/statusline.bats`. The widgets worth having (model name, git branch) are either already on screen or one line of bash away; the ones that justify the runtime (forecasts, cost) need the usage API.

What was taken instead: the stale-window rule above. What was looked at and left: `statusLine.refreshInterval` in `settings.json`, supported since Claude Code 2.1.97 and accepted at 2.1.323 (`Math.max(1, refreshInterval) * 1000` in the bundle). It is unset here on purpose. The only element that would benefit is the reset countdown, whose finest unit is the minute, and the cost is a process spawn every N seconds for the whole session.

## Measured non-defects (review of 2026-11-14)

A countdown under 60 seconds renders `(0m)`: `format_reset` floors to whole minutes, so `resets_at = now+30` prints `7d: 12% (0m)`.
It is reachable, since the CLI keeps a window whose `resets_at` is strictly in the future, and it is visible for at most one minute per window.
Left as is: the text is true, and clamping to `1m` or printing `<1m` would say less.

The `-le` in `unless_reset` is not pinned against `-lt`.
The two differ only for a cached window whose `resets_at` equals the current second, and the CLI's `wt()` already drops any window whose `resets_at` is not greater than now, so no live or cached payload reaches that second in a way a reader could see.

The suite pins what a one-line mutant used to survive: the colour thresholds (the 85 and 70 cut-offs that once tripped a point late), the 6 h retention from below as well as from above, the plain ISO 8601 `resets_at` and the unparseable ISO one, and the no-stderr, exit-zero contract with a cache directory that cannot be created.
The `rm -f` on a failed write is not pinned: reaching it needs a filesystem that accepts the temporary file and then refuses the `mv`, which no payload produces.
