# Claude Code statusline

`claude/.claude/statusline.sh` renders `Context N% | 5h: N% (reset) | 7d: N% (reset)` from the JSON the CLI pipes to the `statusLine` command declared in `claude/.claude/settings.json`.
It has no dependency beyond `jq`, `awk` and coreutils, and it must never write to stderr or exit non-zero: the CLI renders whatever lands on stdout, so a failure shows up as a mangled line rather than an error.
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

`resets_at` is a Unix epoch as a number. The script also accepts an ISO 8601 string through `fromdateiso8601`, so a schema change in that direction degrades to a correct countdown instead of a wrong one.

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

`~/.cache/claude-statusline/last.json` exists to carry the rate-limit segments through the renders where `rate_limits` is absent from the payload. It holds `{rate_limits: ...}` verbatim and is read only while its mtime is under `CACHE_MAX_AGE` (6 h, one full window).

**A live payload carrying any window is authoritative, and the cache is not consulted at all.**
Per-window fallback was rejected: a window the server has stopped reporting would be re-read from the cache and re-persisted on every render, so a stale value would display forever with no way to age out. Whole-file replacement keeps the mtime an honest freshness signal for everything inside.
The write is therefore a replace, not a merge, and it fires whenever either window is live, which is why a payload carrying only `seven_day` still refreshes the file. The previous gate keyed on the five-hour window alone and had frozen the cache from 2026-11-11 onward.

A failed atomic write removes its own `.tmp` rather than leaving one beside the cache.

`unless_reset` drops a cached percentage whose `resets_at` has passed, because the retention window (6 h) outlives the five-hour window it caches: a 4 % read five hours ago describes a window that has since rolled over to near zero, and `--` is the honest answer. A cached window reporting no `resets_at` is kept, there being nothing to decide on. Borrowed from ccstatusline, whose v2.2.32 notes list the same rule as "stale usage fallback drops windows that have reset".

## ccstatusline (evaluated 2026-11-13, not adopted)

`sirmalloc/ccstatusline`, MIT, TypeScript, 13.6k stars, the npm package behind most Claude Code statusline screenshots. Its feature set is an order of magnitude wider: powerline rendering, a React/Ink configuration TUI, multi-line layouts, per-widget colours, git and JJ widgets, block timers, usage forecasts, cost tracking and spend-limit widgets.

Not adopted. It spawns a Node or Bun process on every repaint, queries an Anthropic usage API with its own backoff, credential lookup and per-account cache, and keeps its configuration in `~/.config/ccstatusline/settings.json`, outside the stow tree. The script it would replace is one `bash` plus two `jq` calls per render (the live parse, then either the cache read or the cache write, which are exclusive branches), has no network surface, no credential access and no state beyond a cache of a few hundred bytes, and is pinned by `_meta/tests/statusline.bats`. The widgets worth having (model name, git branch) are either already on screen or one line of bash away; the ones that justify the runtime (forecasts, cost) need the usage API.

What was taken instead: the stale-window rule above. What was looked at and left: `statusLine.refreshInterval` in `settings.json`, supported since Claude Code 2.1.97 and accepted at 2.1.323 (`Math.max(1, refreshInterval) * 1000` in the bundle). It is unset here on purpose. The only element that would benefit is the reset countdown, whose finest unit is the minute, and the cost is a process spawn every N seconds for the whole session.
