# DESIGN-OPENCODE-HARNESS.md

Design note for giving opencode access to the Claude Code profile, decided 2026-09-21 after a `/workflow:reco` and validated by the user the same day.
This note is tracked by the parent repository since `797548b`, 2026-11-07, which moved the allowlisted names of `.claude/.gitignore` into it; the reproducible side is `_meta/notes/opencode-harness-setup.md` (procedure and `showboat verify` checks) and the "Local coding agent" section of `_meta/notes/dotfiles-bootstrap.md`.
Sequencing against the model lives in `DESIGN-GPU-REMOTE.md` § "The harness is sized on the 9B, which is fetched before the harness is built", steps 7 to 11.

## Little is injected, everything is readable, and budget is the constraint

Out of scope: porting the Stop and SessionStart hooks, the MCP servers, rewriting skills for opencode.

Why budget governs: opencode injects `instructions` files in full on every request and rebuilds the system prompt each time (anomalyco/opencode#48778), and llama.cpp re-processes the whole prompt on hybrid models at every cache reset (ggml-org/llama.cpp#21831).
Every token injected up front is paid again and again; a file read on demand is paid once, when needed.

## Instructions come from a short global `AGENTS.md` that points into `~/.claude`

`opencode/.config/opencode/AGENTS.md` holds the behavioral rules of `CLAUDE.md` that hold outside Claude Code, selected by the criterion of "`AGENTS.md` keeps what any agent can apply, 2026-09-21".
Its existence switches off opencode's fallback load of `~/.claude/CLAUDE.md` (docs, "Rules": "`~/.claude/CLAUDE.md` (used if no `~/.config/opencode/AGENTS.md` exists)"), which is the intent and needs no environment variable.

Rejected: letting the fallback load `CLAUDE.md` whole (15k tokens per request, plus Claude-only instructions naming `Skill`, `Agent`, `AskUserQuestion` that mislead a small model), and listing the rules under `instructions` (injected in full, 150 KB).
opencode has no equivalent of the `paths:` frontmatter of Claude Code rules, and does not resolve `@file` imports (anomalyco/opencode#49782).

## Plugin skills are exposed through a link farm that a script regenerates

A new `bin/.local/bin/opencode-skills-sync` maintains one symlink per enabled plugin skill in a dedicated directory outside the dotfiles, which `opencode.json` declares under `skills.paths`, and `_meta/tests/opencode-skills-sync.bats` pins its behaviour.

Referent: `agent-skills-update` and its suite, which already maintain skill links from an installer's state.

Why a script rather than a path, measured 2026-09-21: each install path carries a version hash that moves on every update, and each holds the whole marketplace repository, so an enabled plugin's path also exposes the skills of plugins that are not enabled, only its entry in `marketplace.json` saying which skills it owns.
A link farm serves at all because opencode's `skill` tool returns the skill's base directory with its body, so relative references to `references/` or `scripts/` keep working through a link.

Weakest assumption: this holds as long as Claude Code keeps the shape of `installed_plugins.json` and `marketplace.json`, which are internal and undocumented.

Rejected:

- `skills.paths` pointing at the install paths directly: breaks on every update, exposes disabled plugins, lists each posit skill five times.
- An opencode plugin computing the paths at startup through its `config` hook: nothing establishes that skill discovery reads the configuration after that hook, and it would be untested JS.

## The seven skills of `hebstr/skills` leave the farm for the clone, 2026-11-08

Decided 2026-11-08 through `/design`, approved by the user the same day, to serve them on `cpd` where Claude Code "will never be installed" and the farm directory is created empty.
The farm stays for everything the Claude Code cache sources; only the user's own seven move.

`opencode.json` gains two `skills.paths` entries, initially `~/Documents/packages/skills/audit` and `~/Documents/packages/skills/workflow`, placed after the farm entry, and `cpd` gains a clone of `hebstr/skills` at that same path, pulled by hand with `git pull --ff-only`.
`opencode-skills-sync` is not touched: no clone source mode, no sibling script.
One stowed `opencode.json` stays valid for both machines, which is the choice the section "The packages are not forked per machine, measured 2026-11-04" of `DESIGN-CPD.md` already made for the whole package.
That choice broke on the skills clone: `cpd` does not use `~/Documents/packages`, its clone lives at `~/.local/share/opencode/skills`, and the stowed `skills.paths` now names that path, so `ju-TP` carries the same two entries pointing at its own clone under `~/Documents/packages/skills`.
The user decided on 2026-11-08 to edit the stowed file directly rather than keep one shared path with a per-machine override: the clone is not synced between the machines, so nothing breaks when the two paths differ, and a local layer was rejected as an invisible second source of truth.
The stowed `opencode.json` carries `~/.local/share/opencode/skills/{audit,workflow}` since that decision; `ju-TP`'s clone lives at `~/Documents/packages/skills`, so the two machines resolve the same entries to different paths, which is the accepted trade of editing the stowed file in place.
The farm entry the file once carried for `cpd` is gone too: the farm directory does not exist there because nothing fills it.

**Why the farm was never required for these seven**: the three reasons this note gives for the farm above are all properties of the Claude Code cache, and a git clone has none of them. No version hash moves under it, no disabled sibling plugin shares its directory, and nothing is listed five times.

Measured 2026-11-08 on `ju-TP`, opencode 1.19.5, `OPENCODE_CONFIG` on a scratch config, output redirected to a file and never piped:

- the two clone group directories alone resolve all seven at `~/Documents/packages/skills/{audit,workflow}/*/SKILL.md`, exit 0, empty stderr. opencode reads a plain directory of skill directories with no symlink layer, which the reco had left as "unmeasured and not needed";
- the farm and the two clone paths declared together, clone last, give 66 skills, the same count as the farm alone, each of the seven resolving exactly once and from the clone. The later path wins the collision, silently;
- the ids stay flat (`walkthrough`, `sweep`, `write`), as they already are through the farm, so no `audit:` namespacing is lost or gained.

Weakest assumption, tested: the later `skills.paths` entry wins, so the clone shadows the farm. If a future version reversed that precedence, `ju-TP` would fall back to the farm copy, which is today's behaviour, and `cpd` would be unaffected, its farm being empty.

What it trades away: the farm's coupling to `enabledPlugins`, so disabling the `audit` plugin in Claude Code no longer hides those skills from opencode, and on `ju-TP` opencode now serves the working clone, which can hold prose the plugin cache does not have yet. Both are accepted on a solo setup where the same person owns both harnesses, and the second lands on the bench alone: the user stated on 2026-11-08 that the real use of opencode is on `cpd`, `ju-TP` keeping the install to write and measure the harness.

Rejected, each on a measurement of that day:

- **A clone source mode in `opencode-skills-sync`**, which was the reco's step 0: `skill_dirs()` needs no new parsing, only the loss of its `installed_plugins.json`, `settings.json` and `enabledPlugins` requirements, but nothing on `cpd` would ever call it, there being no `sys-update` and no `claude-plugins-update` there. Buildable the day per-plugin enablement matters on that machine.
- **A dotfiles submodule** instead of a second clone: dotfiles has none today, every clone and pull gains a step, each skill change owes a wiring commit, and the submodule would live under `~/dotfiles` while the editable clone lives under `~/Documents/packages`, so the two machines would stop agreeing on one path and one config.
- **An HTTP catalogue**, which opencode supports natively: the published schema describes `skills` as "Additional paths or URLs to discover skills from", the documentation gives "An HTTP catalog is a base URL with an `index.json` file" downloading `<base-url>/<entry>/<file>`, and the installed 1.19.5 binary carries `SkillDiscovery.pull` fetching that `index.json`, so the route exists on the version that runs here. Its price is a generated manifest enumerating every file (30 across the seven), a `version` integer to bump per skill or the cache serves stale prose with no signal, and a CI gate against drift. It is the route for a machine where git is not already the transport, or for a third party, and that is its reopening condition.
- **`npx skills add hebstr/skills`**: see `DESIGN-AGENT-SKILLS.md`, section "The `skills` CLI lands in `~/.agents/skills` whatever agent is named, measured 2026-11-08".
- **Copying the seven bodies into the `claude` stow package**: breaks the reco's rule of one `SKILL.md` with no duplicated prose.

Open on purpose: the clone's freshness on `cpd` depends on a pull that nothing triggers, which is the same posture `DESIGN-CPD.md` § "Open points" already records for the dotfiles clone itself.

Applied the same day in `8047880`, on `ju-TP`: the two `skills.paths` entries, the `external_directory` allow above, and the records. The clone on `cpd` followed the same day at `~/.local/share/opencode/skills`, with its paths written into the stowed file in place of the shared path: `opencode debug skill` resolves all seven from it, and a live `opencode run` loaded the `reco` skill through the `skill` tool (see `_meta/notes/opencode-cpd-setup.md`).
Still owed on `cpd`: whether `write` and `reco` run to completion as full passes rather than loading; whether `OPENROUTER_API_KEY` has an outbound path there, which the three cross-provider skills need; and whether `walkthrough`, `blindspot` and `skill-adversary` survive dispatching a bundled agent definition opencode does not read.

A standing coupling the change leaves behind: the `showboat verify` check of `_meta/notes/opencode-harness-setup.md` that prints `jq -c '{model, instructions, permissions: ([.permissions[].action] | unique), skills}'` pins the `skills` object verbatim, so any later edit to `skills.paths` makes that expected output false and has to carry it.

## What the model sees is filtered by `permission.skill`

Every visible skill's description sits in the `skill` tool's own description, so the listing is paid on every request; opencode removes a skill set to `deny` from it.

- `deny`: the claude.ai skills under `~/.claude/skills/synced/` that call `mcp__` tools opencode has no equivalent for, or that make no sense here.
  Decided 2026-09-21: the MCP servers stay out, their tool definitions would cost more than they return on a 9B.
  It read "the skills that depend on an MCP server opencode does not run (litrev's five)" until 2026-11-05, when the user removed those five denies, the skills themselves having gone (`project_litrev_plugin_status.md`).
- `ask`: the skills carrying `disable-model-invocation: true`, which opencode ignores, plus `commit`.
  A user-level skill gated on explicit invocation needs its `ask` key here, opencode having no equivalent of the flag.
  Reconfirmed 2026-11-05 on opencode.ai/docs/skills: the keys it reads are `name`, `description`, `license`, `compatibility` and `metadata`, and "Unknown frontmatter fields are ignored", so the flag is inert there and `permission.skill` is the only lever; `deny` hides a skill from the agent and `ask` prompts before loading.
  **This list drifts as skills are added, and nothing warns.** Audited 2026-11-05 by intersecting the names `opencode debug skill` reports with the files carrying the flag: seven were discoverable and unruled, so the model could fire them (`prune`, `reco`, `review-prose`, `sweep`, `sync`, `typst-review`, `write`), three synced skills were unusable here and unruled, their bodies calling `mcp__` tools opencode has no equivalent for (`built-in-browser`, `chrome-browser`, `computer-use`), and one rule named a skill that no longer exists (`claude-automation-recommender`), as the five `litrev` denies did until the user removed them the same day.
  Left unruled on purpose after that audit: `deep-research`, `docx`, `pdf`, `pptx` and `xlsx`, which name no `mcp__` tool and may work here; `google-workspace`, which needs connectors but names none in its body, so the test does not settle it; and `skill-creator`, for the duplicate-resolution reason above.
  `commit` lost the flag on 2026-09-22 (`.claude/PLAN-SESSION-DISCIPLINE.md`) and stays at `ask` for its own reason: its closing procedure needs the write journal, `CLAUDE_CODE_SESSION_ID`, the Agent tool and the Stop gate, none of which opencode has, and the `AGENTS.md` mirror carries the commit format on that side.
  Kept at `ask` rather than `deny`, decided by the user on 2026-09-22.

## Hooks run through one opencode plugin that calls the existing scripts

`opencode/.config/opencode/plugins/claude-hooks.ts` runs the Claude Code hook scripts unchanged, by translating opencode's arguments into the payload they read on stdin, and refuses ahead of them any edit resolving under the Claude Code profile (see "The first live run on the 9B, 2026-09-21").

Not ported: `sweep-stale-consolidate-locks.sh` (Claude Code internals), and the global memory index, read on demand rather than injected, Claude Code itself having loaded it through `autoMemoryDirectory` since 2026-09-27; a project's own `.claude/memory/MEMORY.md` comes through `instructions`, see "A project's `.claude/` is loaded like Claude Code loads it, 2026-09-21".
The Stop hook's re-activation cannot be done from a plugin (anomalyco/opencode#12472).

## Permissions allow reading `~/.claude` and forbid writing it

`external_directory` set to `allow` on `~/.claude/**` and, since 2026-11-08, on `~/.local/share/opencode/skills/**`, the skills clone path the section "The seven skills of `hebstr/skills` leave the farm for the clone, 2026-11-08" serves; skill directories are already allowed by opencode itself, but this block opens on `"*": "ask"`, so a `templates/` or `scripts/` read under the clone would have been auto-rejected under `opencode run` without it.
The farm had an allow of its own until the same day; it left with the `skills.paths` entry, so the block's four rules are `*`, `/tmp/**`, `~/.claude/**` and the clone path, verified 2026-11-11.

The write half did not hold: as first written, `edit` was set to `deny` on `~/.claude/**`, and the live run of 2026-09-21 wrote there despite it, opencode matching `edit` patterns against a path relative to the project (see "The first live run on the 9B, 2026-09-21").
The `edit` patterns are gone, the plugin guard and the `bash` permission carrying the refusal instead (see "`bash` asks unless a command is on a read-and-gate allowlist, 2026-09-21").

## What the first implementation settled, 2026-09-21

- A skill present twice, synced from claude.ai and as a plugin, is kept by opencode in the last copy scanned, with a warning: `skill-creator` resolves to the plugin copy, scanned after `~/.claude/skills/synced/`, so no deny is needed.
  The five litrev skills parse despite their non-strict YAML, which opencode may drop silently (anomalyco/opencode#42350); those skills are gone since, so this stands as a record of the parser's behaviour rather than of a live case.
- Permission precedence: `evaluate` in `packages/core/src/permission.ts` (v1.18.31) takes the last matching rule (`findLast`), so every permission object in `opencode.json` opens on `"*"` and lists the exceptions after it.

## `AGENTS.md` keeps what any agent can apply, 2026-09-21

Criterion, decided the same day: a rule of `~/.claude/CLAUDE.md` enters when it needs none of Claude Code's own tools and its breach either damages something or recurs every session.
What it admitted is readable in `AGENTS.md` itself; what it kept out is not.
Out: memory and `PLAN.md` discipline, adversarial reviews, subagents, skills and hooks, and the workflow rules a 9B will not practise or whose breach is cheap (the done-list before coding, the consumer test, citation by name, fenced tables under `.claude/`, neutral reframing, "show me how", source ranking, jargon, alignment padding).

Rejected: carrying every agent-agnostic rule (about 8 KB).
Adherence drops as instructions accumulate, more so on small models, which would dilute the hard limits, and a larger copy drifts faster from `CLAUDE.md`.
Pointers were rejected for behavioral rules: a model cannot know to fetch a rule it does not know exists.

Drift is handled by hand, through memory `project_opencode_agents_md_mirror`; a rule the 9B ignores is not answered by widening the file, the live run having answered its breaches with a permission and a plugin guard instead (see "The first live run on the 9B, 2026-09-21").

One rule is mirrored without its mechanism, deliberately: the `.claude/HANDOFF.md` bullet of `CLAUDE.md` names the `handoff` skill as that file's only writer, where `AGENTS.md` keeps the direct write and carries the triggers alone.
That skill cannot run under opencode, `scripts/tail.sh` reading `CLAUDE_CODE_SESSION_ID`, which opencode does not set, and the skill appearing in no entry of `permission.skill` (verified 2026-11-08).

The 8 KB that priced the rejection has since been passed, `AGENTS.md` having gained rules of its own, and what the rejection rests on is accumulation rather than byte count.
Its budget half has decayed, measured 2026-09-30: `~/.claude/CLAUDE.md` was 12,104 bytes against the 57,521 of `b70a9c7` that priced the design, and the memory index 20,661 against 50,732, so the digest weighed 71 % of the file it exists to keep out of the prompt, about 0.9k tokens of an 18.4k fixed part.
What has not decayed is the other half, the Claude-only instructions that mislead a small model, which `_meta/notes/zotero-agent-access-reco.md` gives evidence for: its "Where to look for more" wording is a candidate cause for the 9B never calling its own `skill` tool, so whether a hand-maintained digest still earns its drift risk is open.
The model that reads the file is no longer the 9B the selection was sized on: `opencode.json` defaults to `cpd/qwen3.8-27b`, read 2026-11-08, the 9B of `ju-TP` staying the floor the accumulation half is argued against.

Why the guard protects two roots rather than one: every file under `~/.claude` that matters resolves into `~/dotfiles/claude/.claude` through stow, and `AGENTS.md` itself tells the model to edit the resolved path of a symlink, so a refusal on `~/.claude` alone would have been bypassed by following the rules.

## The hooks plugin translates the payload and reports back to the model, 2026-09-21

`opencode/.config/opencode/plugins/claude-hooks.ts`, stowed the same day, pinned by `_meta/tests/claude-hooks-plugin.bats`, which drives the plugin through `node` against stub hook scripts under a fake `HOME`.
Since the port of 2026-11-11 the suite's driver stands in for the V2 host: it collects what `setup()` registers through a recording context, then fires one hook against an event shaped like the host's.

- It covers the `edit` and `write` tools, the only ones opencode gives a non-GPT model: `apply_patch` replaces them for `gpt-*` ids alone (`registry.ts`, v1.18.31).
- Unlike Claude Code, where a PostToolUse hook's output never reaches the model on exit 0, `format-on-edit.sh`'s report (a `jarl` or `shellcheck` finding) is appended to the tool output, so the model sees what the gate found on the file it just wrote.
- opencode's built-in formatters are off unless `formatter` is set (`if (!cfg.formatter)` in `format/index.ts`, the log reads "all formatters are disabled"), so nothing formats a file twice.
- No gate exists for TypeScript on this machine: no rule file, and `node` strips types without checking them.

Both hook scripts carry a one-line comment naming the plugin as a second producer of their payload, since no test ties the keys they read to the ones the plugin writes (its suite stubs them).

## The first live run on the 9B, 2026-09-21

`opencode run` against the 9B at 98304, from a throwaway git repository in the session scratchpad, `llama-session` in the background.

- A one-line bug fix asked in French: read, edit, answer in French with no dash, 26 s end to end.
- The fixed part weighs 18410 tokens, against 10942 with every skill denied; the difference matches the visible listing (7559 tokens under the model's own `/tokenize`, against 12093 had the denied skills stayed listed).
  **`deny` does remove skills from what the model receives.** A project-level `"*"` does not override the global one's position: object keys keep the position the global file gave them, so a project `"*": "allow"` changed nothing and a project `"*": "deny"` left the twelve `ask` skills visible.
- The plugin fires: an `edit` adding an em dash to a `.md` was refused with `prose-lint`'s message, and an `edit` of a `.sh` came out quoted by `shellharden` through `format-on-edit.sh`.
- **The 9B worked around the refusal**: it rewrote the `.md` through the `bash` tool with `printf`, against two rules of `AGENTS.md` (investigate every error, never change a file through the shell).
  The prompt demanded the exact line, which a model may read as outranking a hook, but a hook refusal circumvented by the shell is the failure the plugin exists to prevent.
- **The `edit` deny on `~/.claude/**` does not work**: `write` created `~/.claude/opencode-probe.md` (removed at once).
  `write.ts` asks the `edit` permission with `path.relative(instance.worktree, filepath)`, so an absolute pattern never matches, and no relative pattern can name `~/.claude` from every project, its relative spelling changing with the working directory.
- A plugin skill loads on demand: `cli` from `r-lib`, the model citing `cli_abort()` and the link-farm base directory.
  A denied skill (`ooo`) is refused with the rule list.

Two remedies went in the same day, the plugin guard and an `AGENTS.md` rule reporting a refusal rather than redoing it another way, and were run again live:

- **Neither closed the hole on the second run, because the 9B went through `bash` both times.** Asked to create `~/.claude/opencode-probe.md`, it ran `mkdir -p ~/.claude && echo 'test' > ~/.claude/opencode-probe.md` straight away, never meeting the guard (probe removed).
  Refused by `prose-lint`, it rewrote the `.md` with `cat > … << 'EOF'`, the new rule notwithstanding.
  opencode's default `bash` permission is `allow`, so nothing stood in the way.
- How opencode matches `bash` patterns (`tool/shell.ts`, v1.18.31): commands are parsed with tree-sitter and each is matched by its full source text, redirections included (`source()` returns the whole `redirected_statement`), last matching rule winning.
  An allowed `"cat *"` therefore also admits `cat > file`, unless a later rule such as `"*>*"` takes it back.

## `bash` asks unless a command is on a read-and-gate allowlist, 2026-09-21

Decision of the user the same day, among three: `permission.bash` opens on `"*": "ask"`, allows by prefix the read commands and the gate tools of the rule files, and closes on `"*>*": "ask"`, which takes back any command carrying a redirection.
It is Claude Code's model: every shell command that could write goes before the user, so a heredoc used to get round a refusal is shown rather than run.

Left on `ask` on purpose: whatever runs arbitrary code or writes without a redirection (`sed`, `find`, `cp`, `mv`, `rm`, `uv run`, `Rscript`, `python`, and the writing `git` verbs until they moved to "Git writes: `add`, `commit`, `rm` and `mv` ask, the other verbs are denied, 2026-09-25" below). `sed` is the one that later gained an exception, its reading form only, in "The read allowlist widened, 2026-11-05".
The final rule also catches `2>&1`, which will cost the odd needless prompt; an exception for it would admit `cat > f 2>&1`.

Rejected: a heuristic guard in the plugin parsing commands for writes (bypassable through a variable, a subshell or a script, and blind to a heredoc into a project file), and `bash` on `ask` wholesale (every `rg` and every gate run to approve).

### The read allowlist widened, 2026-11-05

The user reported needless prompts, citing `ls`. `ls*` was already allowed: what prompted was `cd`, absent from the list, because each command of a compound is matched on its own (see the tree-sitter finding above), so `cd /foo && ls` asked on its first half. Thirty-odd read commands went in: `cd`, `which`, `type`, `basename`, `dirname`, `realpath`, `tree`, `du`, `df`, `date`, `uname`, `nproc`, `free`, `id`, `hostname`, `printenv`, `grep`, `diff`, `cut`, `tr`, `sort`, `uniq`, `jq`, `sed -n`, and the reading `git` verbs `ls-files`, `rev-parse`, `check-ignore`, `cat-file`, `describe`, `shortlog`, `grep`, `remote -v`, `remote get-url` and `config --get`.

Three take-backs sit after them, since the last matching rule wins: `sort*-o*` and `tree*-o*` for the output flag that is each one's only write path, and `sed*-i*`, which catches `sed -n -i` slipping through the `sed -n *` allow and also `--in-place`, the glob matching the `-i` inside it. `env` was deliberately left out: `env VAR=x <cmd>` runs an arbitrary command, so allowing it would allow everything.

The take-backs were first written anchored, `sort -o*` and `sort --output*`, and measured useless: against `sort -k1 -o out` neither matched, the flag not sitting first. Unanchored, `sort*-o*` catches both the separated `-o out` and `--output=f`, which makes the second pattern redundant. What no glob catches is a combined short flag, where the `o` follows another flag letter rather than a hyphen, so the substring `-o` never appears.

**The request was to align on Claude Code's permissions, and that is not what was done.** The `deny` lists were already identical, pattern for pattern, and opencode's two extra `ask` entries (`*git rm*`, `*git mv*`) are the 2026-09-25 decision that `AGENTS.md` mirrors. The remaining difference is the default: Claude Code carries a bare `Bash` in `allow`, where opencode opens on `"*": "ask"`. That gap stays, recommended against aligning on 2026-11-05 and left to the user: Claude Code can afford allow-by-default because `git-write-guard.sh` and the edit hooks catch what slips, and opencode has no such layer, its permission list being the whole guard. The live run of 2026-09-21 recorded above is the evidence, the 9B having twice reached `~/.claude` through the shell while `bash` defaulted to `allow`.

Four residuals are accepted rather than closed, each a write that reaches the disk without a prompt: a combined short flag ending in `o`, for the reason above; a second positional argument no glob distinguishes from a pipeline use; a write command inside an otherwise silent filter; and two that write but need root. Each needs a form a coding agent does not emit by accident, and each writes one named file rather than deleting anything, which is why they are accepted here instead of costing the `sort`, `uniq`, `tree` and `sed -n` allows that remove the prompts this section exists to remove.

Unverified: that the widening removes the prompts in practice, opencode's model pointing at `cpd` and no permission dry-run existing, so only the rule order was checked here (`opencode debug agent build` reports 126 bash rules, first `*` on `ask`, last `*git mv*` on `ask`). The glob behaviour of the take-backs was measured directly, with `case` against the candidate command strings.

Verified live on the 9B the same day, under `opencode run`, where `ask` is auto-rejected: the probe under `~/.claude` came through `write` this time and the plugin guard refused it, the model reporting the refusal; refused by `prose-lint`, the model tried `sed -i` and the `bash` rule stopped it, the file left untouched; `rg -c` ran unprompted.
The model still reaches for the shell after a refusal, the `AGENTS.md` rule notwithstanding: the permission is what holds, not the instruction.

## Git writes: `add`, `commit`, `rm` and `mv` ask, the other verbs are denied, 2026-09-25

opencode is the second adapter of the contract decided in `.claude/DESIGN-COMMIT-GUARD.md`, section "Any agent runs `git add` and `git commit` at closure, each call confirmed in its native permission dialog": the agent shows the commit block, runs it as shown, and the permission prompt is the confirmation.
`permission.bash` ends on the four `ask` rules for `git add`, `git commit`, `git rm` and `git mv` (the last two by the decision "every git write verb is gated" in that section), placed last so that the last-match-wins evaluation keeps them, and written as substrings (`"*git add*"`) so that they still catch a compound command if opencode ever matches the whole command string, as its V2 core on `dev` does.
Before them, `opencode.json` denies the other write verbs of Claude Code's `deny` list in their canonical prefix form, placed after `"*>*": "ask"` so that a redirection cannot turn a deny back into a prompt; a rerouted form (`git -C . push`) still falls to `"*": "ask"`.
The hardening patterns of the third `git-write-guard.sh` walkthrough (`git config core.hooksPath`, `git apply -R`, `git checkout-index -f`, `git read-tree -u` and their long spellings) are prefix patterns where Claude Code's guard reads the parsed command, so a reordered spelling matches none of them and falls to `"*": "ask"` on opencode, the same accepted class as `git -C . push`.

### The deny patterns moved from prefix to substring form, 2026-11-08

The `git -C . push` bypass was measured live in run `0422e28c`: a compound command `cd /home/edjulien/dotfiles && git push` was rewritten by the shell scanner into `git -C /home/edjulien/dotfiles push`, which matched an allow rule for `git -C *` that had been added during the session, and executed without a prompt.
The fix moved every write-verb deny from its canonical prefix form (`git push*`, `git reset*`) to a substring form (`git*push*`, `git*reset*`), one pattern per verb, which covers `git <verb>`, `git -C <path> <verb>`, and any other flag-prefixed spelling in a single rule.
Twenty-seven patterns replaced forty-eight: the old list carried both the bare prefix and a `-C` variant for each verb, plus eleven separate `git branch` subflag patterns that collapse into one `git*branch*`.
The read allowlist is untouched: its patterns (`git status*`, `git diff*`, etc.) stay in prefix form because they are allows, and a false positive on an allow is less dangerous than a false positive on a deny.
Accepted: an "always" answer approves `git commit *` for the rest of the session.
The prompt itself has not been tried live.

## A project's `.claude/` is loaded like Claude Code loads it, 2026-09-21

The user flagged the gap after the harness was declared done: opencode reads a project's root `AGENTS.md` or `CLAUDE.md` but never `.claude/CLAUDE.md` (anomalyco/opencode#17436), while the global `CLAUDE.md` makes `.claude/` the home of every project's Claude files.
Decided the same day: `opencode.json` lists `".claude/CLAUDE.md"` and `".claude/memory/MEMORY.md"` under `instructions`, the two files Claude Code loads itself, and `AGENTS.md` carries the rule on `.claude/PLAN.md` instead, that file changing every session and so staying out of the injected set.

Why `instructions`: `session/instruction.ts` (v1.18.31) resolves a relative entry with `globUp(instruction, ctx.directory, ctx.worktree)`, walking up from the working directory to the git root and ignoring an absent file, so one global line covers every project and every subdirectory.
A rule in `AGENTS.md` alone was rejected, the 9B having shown on step 10 of `DESIGN-GPU-REMOTE.md` that it does not reliably follow one; so were a per-project `AGENTS.md` symlink and an injection through the plugin's experimental `experimental.chat.system.transform`.

Measured live on the 9B the same day, `opencode run`, largest prompt of each run:

```
| Directory | Fixed prompt | Difference |
|---|---|---|
| git repository with no .claude/ | 18525 | reference |
| md-nesrine root | 34893 | +16368, its 64 KB .claude/CLAUDE.md |
| md-nesrine/lib | 34894 | same, found by walking up |
| ~/Documents/sandbox/md-nesrine, not a git repository | 44062 | +25537 |
```

In md-nesrine and in its `lib/`, asked what one of the project's columns means without reading any file, the model answered as the project's `CLAUDE.md` defines it.

**Outside a git repository the walk climbs to `~` and injects the global profile**: the +25537 tokens match `~/.claude/CLAUDE.md` and `~/.claude/memory/MEMORY.md`, which `AGENTS.md` exists to keep out of the prompt.
`~/Documents/sandbox/` holds such directories, so the case is not hypothetical.

Decision of the user the same day, a guard rather than a usage rule: the plugin's `experimental.chat.system.transform` removes the two blocks, rebuilt verbatim as `instruction.ts` writes them.
Since the V2 port of 2026-11-11 the hooks are `ctx.session.hook` on `context`, `compaction` and `generate`, the verbatim reconstruction is kept and a second net was added on the instructions metadata; the walkthrough of the same day settled both the three names and the fact that the second net cannot fire (see "The strip owes three hook registrations, and the metadata net is unreachable, 2026-11-11").
What the guard answers has narrowed: V2 no longer walks up to `~` from a directory outside a git repository, so only the stow-source case of running inside `~/dotfiles/claude` still leaks, and the strip was watched removing it live (see "What the live run on the 9B settled, 2026-11-11").
Cutting by what follows a block was rejected, since the next block's opening text (the skills preamble) is opencode's internal wording.
The cost: the hook is marked experimental, and a changed block format makes the guard remove nothing without breaking anything, which the plugin suite and the trace's checks would catch.
Measured again live: 18418 tokens outside git, back at the reference, 34952 in md-nesrine with its rules still known.

## The plugin's first review walkthrough, 2026-09-21

`posit-dev:critical-code-reviewer` on `claude-hooks.ts`, five findings, the two Required ones confirmed by L1 and by `openai/gpt-5.6-sol` through OpenRouter.
- An `edit` with an empty `oldString` creates the file in opencode, a case Claude Code's Edit never has: the hook read `old_string: ""` against a missing file, exited 3, and let prose-lint go unrun.
The plugin sends it as `content`.
- opencode's `edit` applies the first of nine replacers, fuzzy ones included, while the hook replays `oldString` verbatim and so linted the pre-edit file.
An `edit` of an existing `.md`/`.qmd`/`.Rmd` whose `oldString` is not verbatim is refused; a CRLF file edited with an LF `oldString` is refused too, accepted as failing closed.
- The strip also removes `~/dotfiles/claude/.claude/CLAUDE.md` and its `MEMORY.md`, which the walk finds when opencode runs inside `~/dotfiles/claude`; one `PROFILE_ROOTS` now serves the guard and the strip.
- `runHook` runs the script in its own process group and kills the group after 60 s: a `spawn` timeout alone kills `bash` while a formatter it started keeps the pipes open and `close` waiting (measured).
A timeout stays advisory.
`CLAUDE_HOOKS_TIMEOUT_MS` overrides the delay so that the case "a hook whose child keeps the pipes open is killed at the timeout" runs in half a second; a kill aimed at `bash` alone fails it.
- Noted, not changed: a dangling symlink into the profile passes the guard, since `existsSync` is false on it and the link is taken as a missing tail.
Creating one needs `bash`, which already asks and could write there directly.

`format-on-edit.sh` runs prose-lint only under `*/dotfiles/claude/.claude/*`, which the guard forbids to opencode, so nothing after an edit reports dashes in an ordinary `.md`: the pre-hook is the only check before a commit.

## The harness migrates to opencode V2, decided 2026-11-11

Both machines move, and the configuration is converted to the native V2 shape rather than left on the compatibility layer.
Approved by the user on 2026-11-11 after a `/design` run on `ju-TP` that measured V2 2.2.7 in session instead of reading the documentation.

The order is forced by a compatibility layer that runs one way: V2 reads a V1 configuration and normalizes it in memory without rewriting the file, while opencode.ai/docs/migrate-v1 warns against pointing V1 at a converted one.
`opencode/.config/opencode/opencode.json` is a single stow source shared by `cpd` and `ju-TP` through git, so the conversion comes last, after both machines run V2.
The plugin is the hard blocker: a V1 plugin implementation does not run under V2 at all, so between a machine's V2 install and the port, `prose-lint-pretool.sh`, `format-on-edit.sh` and the `PROFILE_ROOTS` guard are all off there.

Steps, ordered by dependency, the minimal viable core being 0 to 3:

0. `~/.opencode/bin` on the `PATH` through `bash/.profile`, then `npm uninstall -g opencode-ai`. Once per machine. **Done on `ju-TP` 2026-11-11**: the `PATH` block sits before the `$HOME/.local/bin` one so that `~/.opencode/bin` lands ahead of `~/.npm-global/bin`, `opencode` answers `v2.2.7`, and `~/.npm-global/lib` is empty.
1. The `edit` deny of the next section, which closes the write window without waiting for the port. **Done 2026-11-11**, and `opencode debug agents --standalone` resolves both denies.
2. The plugin port and its suite, `_meta/tests/claude-hooks-plugin.bats` green before and after. **Done 2026-11-11**, 34 tests green before, 38 after, and V2 loads the ported file with no error in its log.
3. One live `opencode run` on the 9B of `ju-TP2`, which settles the payload shape that a stub suite cannot. **Done 2026-11-11**, see "What the live run on the 9B settled, 2026-11-11".
4. `cpd` back in service: stow the ported plugin, and check whether the installer kept the `opencode-serve` symlink it writes beside. **The plugin half is done 2026-11-11**: the ported file is stowed there and the TUI loads it, once `opencode service restart` cleared the V1 module the running service still held, see "Probing a V2 configuration takes `--standalone`, 2026-11-11". The `opencode-serve` half is still owed, with the leftover `llama-server.sh` that `_meta/notes/opencode-cpd-setup.md` § "Deferred" asks about.
5. The native conversion, starting from `opencode debug config`, re-measuring the read allowlist residues of "The read allowlist widened, 2026-11-05" against the V2 shell scanner. **The conversion is done 2026-11-11**, see "The configuration converts to the native V2 shape, 2026-11-11". The residue re-measurement is still owed.
6. The records that hung off the npm install. **Done 2026-11-11**, with step 0, which made them false: `_meta/notes/dotfiles-bootstrap.md` and `_meta/notes/opencode-harness-setup.md` now give the binary installer as the route, the opencode row of `_meta/notes/environment-archive.md` names `~/.opencode/bin/opencode`, `claude/.claude/rules/install.md` and the memory `project_closed_tool_evaluations.md` mark the `allow-scripts=opencode-ai` entry of `~/.npmrc` vestigial against an empty global prefix, `_meta/notes/opencode-cpd-setup.md` drops its 1.19.5 claim, and the `opencode plugin dependency` probe of `_meta/cpd/recon.sh`, the ported plugin having no dependency to find, becomes a pair: `opencode service status`, and a `grep` of `~/.local/share/opencode/log/opencode.log` for `loading plugin` and `Plugin failed`. It was `opencode plugin list` for part of that day, which the section on `--standalone` measured as a false negative waiting to happen.

State at the end of 2026-11-11: `ju-TP` runs V2 2.2.7 alone, `opencode` resolving to `~/.opencode/bin/opencode` in a login shell and the npm global prefix being empty; `cpd` runs V2 with the ported plugin stowed and loading, and what step 4 still owes there is the `opencode-serve` symlink.
The stowed configuration is native V2 since the same day, so neither machine reads the compatibility layer any more.

## V2 enforces an `edit` deny on an absolute path, so the profile guard moves into the configuration, 2026-11-11

Two `edit` deny rules take `~/.claude/**` and `~/dotfiles/claude/.claude/**` in the stowed `opencode.json`, and the plugin keeps its own guard once ported.
Both rather than either: the configuration rule is the always-on floor and the only one that covers the `patch` tool, while the plugin resolves symlinks and a missing tail through `realTarget` and returns a message telling the model not to retry by other means.

What makes this possible reverses the measurement of "The first live run on the 9B, 2026-09-21", where an absolute `edit` pattern could never match because `write.ts` asked with a project-relative path.
Measured on 2026-11-11 against 2.2.7: `FileAccess.resolve` hands the permission layer the absolute path when the file sits outside the project and the project-relative one otherwise, and `~` is expanded in the rules an agent resolves, visible through `opencode debug agents` although `debug config` prints the source spelling.
A V1-shaped `permission.edit`, `permission.write` or `permission.patch` all normalize onto the single V2 `edit` action, so the block was written in V1 form until step 5 turned it into `edit` rules of the native array on 2026-11-11.
Checked the same day on both binaries: V2 resolves the two denies to `/home/julien/.claude/**` and `/home/julien/dotfiles/claude/.claude/**`, and V1 1.19.5 parses the block and expands it identically, where it stays inert for the project-relative reason above.

What it does not cover: a write to the stow source made from inside `~/dotfiles`, whose resource is relative there. The plugin guard carries that half.

Rejected:

- **Flipping `~/.claude/**` to `ask` in `external_directory` for the duration of the port**, which was the remedy the migration brief proposed. It blocks reading as well as writing, so it would have cut skill discovery under `~/.claude/skills` for the whole window.
- **The ported plugin guard alone**: it is keyed on one path argument, so the `patch` tool escapes it, and it is off exactly when the plugin is off, which is the window this entry exists to close.
- **The configuration rule alone**: no message reaches the model, and the stow source is missed from inside `~/dotfiles`.

## `**` matches, and a trailing ` *` covers the bare command, measured 2026-11-11

The V2 matcher escapes the regex metacharacters of a pattern, maps `*` to `.*` and `?` to `.`, anchors both ends and compiles with the `s` flag.
So `**` is `.*.*`, equivalent to `*`, and the four `external_directory` rules are live: the reading that would have made `~/.claude/**` already inert is wrong.
A pattern ending in ` *` is rewritten to `( .*)?`, so `git status *` also matches a bare `git status`.
With no matching rule the default is `ask`, but the `build` agent always opens on an allow of `*` over `*`, so an unmatched `edit` is allowed.

## The ported plugin carries no runtime dependency, 2026-11-11

`Plugin.define` is `export function define(plugin) { return plugin }` in `@opencode/plugin@2.2.7`, an identity.
The port default-exports `Plugin.define({ id, setup })` with a value import of `@opencode/plugin`.

Measured 2026-11-11 against the 2.2.7 server: a plain `{ id, setup }` default export fails to load with `SchemaError(Missing key at ["default"])`, so the host demands the marked form even though `define` is an identity.
The remedy is the value import and the `Plugin.define` call, which the 2.2.7 server loads cleanly (probe under a scratch `XDG_CONFIG_HOME`: "loading plugin" with no failure, `setup` registered).

The package is not installed on disk: the 2.2.7 binary serves `@opencode/plugin` from its embedded cache at import time, so nothing goes under `~/.config/opencode`.
The bats driver cannot rely on that, so it registers a resolve hook mapping `@opencode/plugin` to an identity `define` stub before importing the plugin; the suite stays green without a 190 MB `node_modules` tree.

Weakest assumption: the host keeps demanding the marked form and serving the package from its embedded cache. A version that stopped serving it would break the value import at load time, visible in the server log as a module resolution failure rather than a schema error.

## What V2 changes in the plugin's three contracts, measured 2026-11-11

Read from the JS bundle embedded in the 2.2.7 binary and from the type definitions of `@opencode/plugin@2.2.7`.

- **Throwing from `execute.before` still refuses the call.** The host wraps that callback in a try/catch turning any throw into a `Tool.Error` carrying its `message`, and `Tool.execute` triggers the hook before piping into execution, so the failure short-circuits and the message returns to the model. `execute.after` is wrapped without a catch, so a throw there is an unhandled defect: the after hook must not throw.
- **A hook can still rewrite a tool's output, under another name.** The after event is `{ status: "completed", result }` or `{ status: "error", error }`, and the host reads `event.result.output` and `event.result.content` back after the trigger. V1's `output.output` becomes `event.result`, and the hook has to test `status` first.
- **The tool names hold, the path argument does not.** `ctx.tool.list()` on the `build` agent returns `patch`, `edit`, `glob`, `grep`, `question`, `read`, `shell`, `skill`, `subagent`, `webfetch`, `websearch`, `write` and the `opencode_*` session tools; `bash` is now `shell`, a repair table rewriting a model's `bash` call onto it. But `edit` and `write` take `path` where V1 took `filePath`, so a port keeping the old name reads `undefined` and the guard fails open with no signal.

Four further findings bear on the rewrite:

- `patch` is registered for every agent, takes a multi-file `patchText` and carries `permission: "edit"`. It escapes both hook scripts and any guard keyed on a single path, which is the second reason the deny moved into the configuration.
- V2's `edit` rejects an empty `oldString` and points at `write`, so the special case `claudePayload` has carried since "The plugin's first review walkthrough, 2026-09-21" is dead code in the port.
- V2's `edit` retries on its own while ignoring typographic quote, dash and space variants, then trailing whitespace on each line, so the refusal on a non-verbatim `oldString` keeps its reason.
- The instructions system part carries `metadata.experimental.instructions` as `{ key, text }` entries, so the strip can key on the file path instead of rebuilding `Instructions from: <file>` verbatim, which removes the silent failure mode recorded in "A project's `.claude/` is loaded like Claude Code loads it, 2026-09-21". The field is marked experimental and is not updated when a hook edits `text`.

## What the ported plugin no longer says in comments, 2026-11-11

The port of step 2 landed on 2026-11-11 and `rules/code.md` applies to it, so the WHY the V1 file carried in comments lives here.
Most of it already had a home above: the payload translation in "Hooks run through one opencode plugin that calls the existing scripts", the fuzzy-match refusal and the killed process group in "The plugin's first review walkthrough, 2026-09-21", the `instructions` walk in "A project's `.claude/` is loaded like Claude Code loads it, 2026-09-21".
What had none:

- `runHook` ignores an error on the child's stdin. A hook may exit before reading it, which `prose-lint-pretool.sh` does when `prose-lint` is absent, and the resulting EPIPE would otherwise be an unhandled error that kills opencode.
- Exit 2 is Claude Code's blocking signal and the only one the before hook turns into a refusal. Any other non-zero exit stays advisory, as it does in Claude Code.
- `realTarget` walks up to the nearest existing ancestor and reappends the missing tail, because a file about to be created does not exist yet and `realpathSync` would throw on it. Symlinks into the profile are caught either way.
- The after hook returns early unless `event.status` is `completed`, V2 handing an `error` event the same hook with no `result` to append to.

Two comments died with V1 rather than moving: opencode no longer calls every export of a plugin module, the default export being the plugin; and `claudePayload` no longer rewrites an edit with an empty `oldString` into a write, V2's `edit` rejecting that input itself.

The suite grew from 34 tests to 38: the write-shaped empty `oldString` case became its edit-shaped counterpart on a missing file, and four were added, two for the metadata route of the strip, one for the `error` branch of the after hook, and one pinning that `patch` runs no hook.

## What the live run on the 9B settled, 2026-11-11

`opencode run --standalone` against `ju-tp2/qwen3.5-9b` through `llama-session`, on a scratch `XDG_CONFIG_HOME` holding a copy of the stowed configuration, a symlink to the real plugin and a capture plugin loaded after it.

- **The edit payload is `{path, oldString, newString}`**, and `read` takes `path` too. The V1 `filePath` would have left the guard reading `undefined`.
- **The report reaches the model.** The `edit` result's `content` came back as two parts, opencode's own `Edited doc.md (1 replacement)` and the plugin's `format-on-edit.sh:\n1 file left unchanged`. The real content is already an array, so the array branch of the rebuild is the one that runs.
- **A throw still refuses and the model reports it.** An edit introducing an em dash was refused with `prose-lint`'s own message, the file was left untouched, and the 9B asked which dash to use instead rather than reaching for the shell, unlike every run of 2026-09-21 and 2026-11-05.
- **The `edit` denies hold at runtime**, measured by calling `ctx.permission.assert` on four resources from inside a session: both profile roots refused with `Permission denied: edit`, a path under `~/Documents` and a project-relative one allowed.
- Asked to write under `~/.claude`, the 9B refused on its own from `AGENTS.md`, then tried `mkdir` through the shell and was auto-rejected by the `*` ask on `shell`. The guard itself was therefore not reached, which is why the assert above is what measures it.

**The global-profile leak changed shape, and the strip keeps an object.** From a non-git directory directly under `$HOME`, the instructions entry `core/instructions` weighs 10634 characters against `AGENTS.md`'s 10557 bytes, and no entry is keyed on a file: V2 no longer walks up to `~`, so the case measured on 2026-09-21 in `~/Documents/sandbox` is gone.
From inside `~/dotfiles/claude` it is another matter: the entry weighs 41473, which is `AGENTS.md` plus `CLAUDE.md` plus `MEMORY.md` of the stow source, while the part's text weighs 27419, the difference being what the plugin removed before the capture plugin saw it.
So the strip is kept, the verbatim route is the one that fires, and the instructions metadata is a net that has not had to catch anything yet (corrected the same day: it cannot catch anything against 2.2.7, see "The strip owes three hook registrations, and the metadata net is unreachable, 2026-11-11"). The capture also confirms the documented warning that the metadata is not updated when a hook edits the text: it still advertises the blocks the strip removed.

## Probing a V2 configuration takes `--standalone`, 2026-11-11

`OPENCODE_CONFIG` is ignored by 2.2.7, and `XDG_CONFIG_HOME` moves only what `opencode debug paths` reports: every other `debug` subcommand is answered by the background `opencode serve --service` process with the configuration it loaded at startup.
A variant is therefore measured with `XDG_CONFIG_HOME` and `--standalone` together, which is how the two sections above were checked.
The `OPENCODE_CONFIG` technique of "The seven skills of `hebstr/skills` leave the farm for the clone, 2026-11-08" no longer works.
`opencode debug skill` is gone, so the tool and skill lists are read from inside a session or through a probe plugin calling `ctx.tool.list()`.
`opencode upgrade` exists and is the candidate route to replace npm in `sys-update`, which step 6 did not do: that step rewrote the records alone, `sys-update` carries no opencode module and its `npm` one still runs `npm update -g` against an empty global prefix (measured 2026-11-11), so the open point below is where this sits.

That same process caches a plugin module by path for its whole lifetime.
A file whose content is replaced at a path the service has already imported keeps serving the old module, and the `watcher started` line the log shows on that very file does not make it reread; a path the process has never imported is taken without a restart, so a newly stowed plugin can work where an updated one does not.
`opencode service restart` is what clears it, measured 2026-11-11 against a probe configuration: a plugin stripped of its `default` export was still listed under its old id by the running service, and listed with no id at all once restarted.
That is what stalled `cpd` on 2026-11-11, `stow` having replaced the plugin's content at a path whose V1 module the running service still held, so the TUI reported `plugin must export a default definition with an id and an effect or setup function` while the file on disk was the ported one.
`opencode plugin list` does list the local plugins and not only the registry's, and it is still no probe: it reports the state the server has already loaded, so it races the load on a cold process.
The first call after a `start` or a `restart` answers `No plugins found` and the second lists them, while `--standalone`, which starts a server per invocation, answers `No plugins found` every time (measured 2026-11-11).
What answers the question instead is the log, `loading plugin` and `Plugin failed` in `~/.local/share/opencode/log/opencode.log`, which is the pair `_meta/cpd/recon.sh` now carries.

## The strip owes three hook registrations, and the metadata net is unreachable, 2026-11-11

Second review walkthrough of `claude-hooks.ts`, run the day of the port on `01d3b18` and on `_meta/tests/claude-hooks-plugin.bats` together, with `posit-dev:critical-code-reviewer`.
It changed the plugin twice and the suite five times; the suite went from 38 tests to 42 and stays the only gate.
None of the five decisions of the port was reopened.

**The strip was registered on one of the three prompt builds.** 2.2.7 dispatches four request kinds onto four hook names, `primary` onto `context`, then `compaction`, `generate` and `title`, and `compaction` and `generate` both build their system array through the same `Uae`, which is where the `Instructions from: <path>` blocks and the `metadata.experimental.instructions` entry are assembled.
So a callback on `context` alone left the profile unstripped in exactly the request where the context is already full.
Every built-in module of the host registers one callback on `context`, `compaction` and `generate`, and the plugin now does the same through a named `strip` and a loop.
Dropping a name from that loop fails that name's test and no other, measured both ways.
The leak this closes is the stow-source one of "What the live run on the 9B settled, 2026-11-11"; from an ordinary project directory there was nothing to strip in any of the three.

**The instructions metadata cannot fire against 2.2.7, and is kept anyway.** The host's state-entry keys are a closed set of seven literals (`core/date`, `core/environment`, `core/instructions`, `core/codemode`, `core/mcp-guidance`, `core/reference-guidance`, `core/skill-guidance`) plus a dynamic `api/<name>` namespace for plugin-supplied entries, and every instruction file is folded into the single `core/instructions` aggregate.
No key is ever a file path, so `named.has(entry.key)` against the four absolute profile paths matches nothing.
This corrects "What V2 changes in the plugin's three contracts, measured 2026-11-11", which read the `{ key, text }` shape off the type definitions and inferred that the strip could key on the file path, and it sharpens "What the live run on the 9B settled, 2026-11-11", which called the metadata a net that has not had to catch anything yet: it is a net that cannot catch anything, not a dormant one.

Kept by the user's ruling on the walkthrough, against the reviewer and against the intra-family L1, which both argued for deleting the branch with its two tests; the cross-provider L2 argued for keeping it and correcting this note instead.
What the argument for keeping has to concede: the branch guesses that a future host would key an entry on an absolute filesystem path, where the host's own convention namespaces every key it has (`core/`, `api/`), so a per-file key would most likely be namespaced too and miss anyway.
The two tests of the metadata route pin a contract of `stripGlobalProfile` rather than one of the host, and `_system_by_metadata` builds an entry shape 2.2.7 does not produce.
Reopen on a host version whose keys are paths, or drop the branch at step 5 when the configuration is converted and the tool surface is re-measured.

One hazard travels with the branch: its removal is `text.replace(entry.text, "")`, so loosening the key test to `core/instructions` would delete the whole aggregate, taking `AGENTS.md` and the project's own `.claude/CLAUDE.md` with the profile.
That is a reason not to loosen it rather than a defect today.

**`runHook` decoded each pipe chunk on its own.** `out += chunk` on a raw `Buffer` calls `toString()` per chunk, so a character split across a chunk boundary became two U+FFFD.
Measured on this machine: 40000 U+2014 through the old form yields 3 replacement characters and a length of 40002 for 40000 characters; `setEncoding("utf8")` on both streams yields 0.
The payload is the live one, `prose-lint` quoting an offending French line whose violation is an em dash.
No trigger existed at the sizes the two hooks produce, one pipe chunk being 64 KiB; the fix replaces an incorrect idiom with its canonical form rather than adding a guard, which is why it was taken rather than noted.

**The one branch of `resultParts` that production takes had no test.** The live run measured a real `edit` result's `content` as an array of parts, and the suite driver only ever built a string, so the array branch was uncovered: replacing its body with `return []` passed all 41 tests while silently dropping opencode's own result part from what the model reads back.
The driver grew an `after-parts` phase and the suite a test that kills that mutant and the `[result.content]` one.

**The `_system_with` fixture joined blocks with one newline where the host joins with two.** The host's renderer is `.join("\n\n")` over blocks whose content already ends in a newline, so two blocks sit three newlines apart, and the fixture was one short.
Correcting it changed four exact-equality assertions and exposed what the old fixture concealed: on the real shape the strip leaves a newline behind, because it removes `<block>\n` out of a `\n\n` gap, so a stripped prompt carries three to four consecutive newlines where the block was.
Cosmetic, a few tokens, and not fixed here: tightening the strip to consume the whole gap is a change to the plugin that no finding asked for.
The assertions now pin the residue, so a later attempt to clean it up is visible rather than silent.

**Noted, not fixed.** `JSON.stringify(result.output)` in `resultParts` is unguarded where the host's own helper wraps its equivalent in try/catch, and a throw from `execute.after` is unhandled by the host.
It is unreachable for `edit` and `write`: their `content` is set, so `resultParts` returns from an earlier branch, and their `output` is a string, which the `typeof` test takes first.
Widening `EDIT_TOOLS` to a tool whose `output` is a non-serializable value, with no `content`, is what re-opens it.

## The configuration converts to the native V2 shape, 2026-11-11

Step 5, applied to `opencode/.config/opencode/opencode.json`.
Two deprecated keys moved: `permission`, an object of four blocks, becomes `permissions`, an ordered array of `{action, resource, effect}` in which `bash` is spelled `shell`; `provider` becomes `providers`, whose entries carry `package`, its value prefixed `aisdk:`, and `settings`, in place of `npm` and `options`.
`model` as a string and `skills.paths` stay, both being in the published schema and in neither deprecation.
`Permission.Ruleset` is an array of objects with `additionalProperties: false` and admits no compact form, so the file goes from 206 lines to 737 for the same 134 rules in the same order: that cost is forced, not chosen.

The equality was established before the file was touched.
`opencode debug config --standalone` normalizes the V1 file to a document; that document, fed back as a configuration, normalizes to itself; and the converted file normalizes to the same document, `diff` clean in all three.
The result validates against `https://opencode.ai/config.json` with zero errors (`jsonschema` 4.10.3, Draft 2020-12), and `opencode debug agents --standalone` still resolves both `edit` denies, `~` expanded to `/home/julien/.claude/**` and `/home/julien/dotfiles/claude/.claude/**`.

The other half of step 5 is untouched: the conversion changes no rule, so the four accepted residues of "The read allowlist widened, 2026-11-05" stand exactly as V1's scanner left them.
The command that section used to count the rules, `opencode debug agent build`, is gone from 2.2.7, whose `debug` subcommands are `agents`, `config`, `heap-dump` and `paths`; the replacement reads them out of `opencode debug agents --standalone` and is in `_meta/notes/opencode-harness-setup.md` § "Checks".

The user narrowed `ju-TP`'s role the same day, from the 2026-11-08 "write and measure the harness" to smoke tests alone, so the shared configuration is read as `cpd`'s.
That is what settles the Better BibTeX JSON-RPC deny which `5d6c755` dropped on 2026-11-08 under a header naming only git permissions: left out rather than restored, the `zotero` package not being among the four stowed on `cpd`.
The record is in `_meta/notes/zotero-agent-access-reco.md` § "La lecture seule tient au seul verrou de Zotero", with what still guards that endpoint.

## Next, in the order agreed on 2026-09-21

1. The user's first interactive trial, in `~/Documents/services/md-nesrine` on a throwaway branch, following `.claude/ESSAI-OPENCODE.md` in that project (untracked there): the model's knowledge of the project rules without being shown them, `/design` as a slash command, a multi-step task with the gate, a hook refusal, a long session through compaction.
   Its results come back in a fresh conversation through the prompt at the end of that note.
2. Then the adversarial reviews, held back so that they do not review a version the trial could still change.
   Still pending: `/audit:blindspot claude/.claude/memory/project_opencode_agents_md_mirror.md`.
   The walkthrough of `claude-hooks.ts` did not wait for the trial: the port made it a review of new code rather than of a version the trial could change, and it ran on 2026-11-11 (see "The strip owes three hook registrations, and the metadata net is unreachable, 2026-11-11").
   A further one is owed only if the trial changes the plugin.
3. Then, depending on what the trial shows: the farm freshness check deferred in `DEFERRED.md`, and the A/B against Gemma 4 12B set out in `DESIGN-GPU-REMOTE.md` § "The choice survives a second search, 2026-09-21".
   The `bash` allowlist was the third item here and did not wait for the trial: the user hit the prompts in real use on `cpd`, so it was widened on 2026-11-05 (see "The read allowlist widened, 2026-11-05").

## Open points

- Bash syntax highlighting in the prompt follows the active theme's flat `syntax.*` tokens (measured 2026-11-11 on 2.2.7: the binary embeds `tree-sitter-bash.wasm`, so shell code is parsed and coloured, but only through those nine colour slots).
  There is no integration with blesh: the TUI reads only the terminal's ANSI palette under `theme.name: "system"`, never a blesh config. To follow a blesh theme, either create a custom theme file in `~/.config/opencode/themes/` whose `syntax.*` tokens match it, or keep `system` and align the terminal palette with the blesh theme. Deferred by the user on 2026-11-11.
- Whether a skill set to `ask` stays usable as a slash command when the user types it: needs the interactive TUI, item 1 of "Next".
- A command on the `bash` allowlist can still write without a redirection if the tool itself writes (`ruff check --fix`, `shfmt -w`, `air format` on any path given): accepted, since these are the gate the model is told to run, but they are not confined to the project.
- The skill farm is resynced only by `claude-plugins-update`, so a plugin auto-update or a `/plugin enable|disable|update` done in Claude Code leaves opencode on the superseded version, or on a disabled plugin's skills, until the next `sys-update`, breaking in the meantime the rule that only an enabled plugin's skills are ever exposed.
  Deferred with a chosen remedy in `DEFERRED.md`, row of 2026-09-21 on the opencode skill farm, whose scope narrowed on 2026-11-08 to the third-party plugin skills: the seven of `hebstr/skills` left the farm, and with it the `enabledPlugins` rule, which the section "The seven skills of `hebstr/skills` leave the farm for the clone, 2026-11-08" accepts losing for them.
- ~~Whether V2 still injects the global profile outside a git repository.~~ Closed 2026-11-11 by "What the live run on the 9B settled, 2026-11-11": the directory-walk case is gone, the stow-source case is not, and the strip stays.
- No update module covers opencode since `npm uninstall -g opencode-ai` ran on 2026-11-11: the `npm` module of `sys-update` now updates nothing, `~/.npm-global/lib` being empty. `opencode upgrade` exists on 2.2.7 and is the candidate, which `rules/install.md` § "One entry point: `sys-update`" would take as an inline module or as a dedicated `opencode-update` script. Nothing keeps opencode current in the meantime.
- Whether a V2 configuration can disable a tool by name, which would retire the `patch` hole instead of leaving it to the `edit` deny. To measure at step 5.
- Whether `~/.claude/skills` leaves `skills` once V2 auto-discovers it. Dropping it is a choice rather than something the compatibility layer did: the normalized array still carried it verbatim on 2026-11-11, beside the two clone paths.
- Whether the `opencode-serve` symlink survived the V2 installer on `cpd`, the installer writing into the same directory. To check at step 4.
- **The four `ask` rules of the git gate miss the `-C` spelling, so `git add` and `git commit` run unprompted through it.** Measured 2026-11-11 with `case` against the rules of the converted file: `git -C /tmp/x add .`, `git -C /tmp/x commit -m x`, `git -C /tmp/x rm f` and `git -C /tmp/x mv a b` all end on `git*` and `allow`, the last-matching `*git add*`, `*git commit*`, `*git rm*` and `*git mv*` needing the literal two-word substring. The deny half was moved to substring form on 2026-11-08 for exactly this reason, after the shell scanner was caught rewriting `cd <dir> && git push` into `git -C <dir> push` (`_meta/notes/opencode-cpd-setup.md`), and the `ask` half did not follow: `git -C <dir> push` is denied today, `git -C <dir> commit` is not even prompted. The one-pattern-per-verb remedy that closed the deny half does not transfer, `git*rm*` matching `git log --format=%s` on the `rm` inside `format` and `git*add*` matching `git log --grep=add`, both measured the same way. What does work, measured 2026-11-11 against twelve command strings, is the anchored form `git -C* add*`, `git -C* commit*`, `git -C* rm*` and `git -C* mv*`, appended after the four current rules: it catches the four verbs in their `-C` spelling and none of the eight reads tested, `git -C /tmp/x log --format=%s` included. Unapplied, the user having asked on 2026-11-11 that the configuration be left alone, and a permission change being theirs. It belongs to the residue half of step 5, with the caveat every measurement of this kind carries here: the model is the shell's `case` glob, no permission dry-run existing to run the rules through opencode's own matcher.
