# DESIGN-OPENCODE-HARNESS.md

Design note for giving opencode access to the Claude Code profile, decided 2026-09-21 after a `/workflow:reco` and validated by the user the same day.
This note is gitignored; the tracked, reproducible side is `_meta/notes/opencode-harness-setup.md` (procedure and `showboat verify` checks) and the "Local coding agent" section of `_meta/notes/dotfiles-bootstrap.md`.
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

`opencode.json` gains two `skills.paths` entries, `~/Documents/packages/skills/audit` and `~/Documents/packages/skills/workflow`, placed after the farm entry, and `cpd` gains a clone of `hebstr/skills` at that same path, pulled by hand with `git pull --ff-only`.
`opencode-skills-sync` is not touched: no clone source mode, no sibling script.
One stowed `opencode.json` stays valid for both machines, which is the choice the section "The packages are not forked per machine, measured 2026-11-04" of `DESIGN-CPD.md` already made for the whole package.

**Why the farm was never required for these seven**: the three reasons this note gives for the farm above are all properties of the Claude Code cache, and a git clone has none of them. No version hash moves under it, no disabled sibling plugin shares its directory, and nothing is listed five times.

Measured 2026-11-08 on `ju-TP`, opencode 1.19.5, `OPENCODE_CONFIG` on a scratch config, output redirected to a file and never piped:

- the two clone group directories alone resolve all seven at `~/Documents/packages/skills/{audit,workflow}/*/SKILL.md`, exit 0, empty stderr. opencode reads a plain directory of skill directories with no symlink layer, which the reco had left as "unmeasured and not needed";
- the farm and the two clone paths declared together, clone last, give 66 skills, the same count as the farm alone, each of the seven resolving exactly once and from the clone. The later path wins the collision, silently;
- the ids stay flat (`walkthrough`, `sweep`, `write`), as they already are through the farm, so no `audit:` namespacing is lost or gained.

Weakest assumption, tested: the later `skills.paths` entry wins, so the clone shadows the farm. If a future version reversed that precedence, `ju-TP` would fall back to the farm copy, which is today's behaviour, and `cpd` would be unaffected, its farm being empty.

What it trades away: the farm's coupling to `enabledPlugins`, so disabling the `audit` plugin in Claude Code no longer hides those skills from opencode, and on `ju-TP` opencode now serves the working clone, which can hold prose the plugin cache does not have yet. Both are accepted on a solo setup where the same person owns both harnesses.

Rejected, each on a measurement of that day:

- **A clone source mode in `opencode-skills-sync`**, which was the reco's step 0: `skill_dirs()` needs no new parsing, only the loss of its `installed_plugins.json`, `settings.json` and `enabledPlugins` requirements, but nothing on `cpd` would ever call it, there being no `sys-update` and no `claude-plugins-update` there. Buildable the day per-plugin enablement matters on that machine.
- **A dotfiles submodule** instead of a second clone: dotfiles has none today, every clone and pull gains a step, each skill change owes a wiring commit, and the submodule would live under `~/dotfiles` while the editable clone lives under `~/Documents/packages`, so the two machines would stop agreeing on one path and one config.
- **An HTTP catalogue**, which opencode supports natively: the published schema describes `skills` as "Additional paths or URLs to discover skills from", the documentation gives "An HTTP catalog is a base URL with an `index.json` file" downloading `<base-url>/<entry>/<file>`, and the installed 1.19.5 binary carries `SkillDiscovery.pull` fetching that `index.json`, so the route exists on the version that runs here. Its price is a generated manifest enumerating every file (30 across the seven), a `version` integer to bump per skill or the cache serves stale prose with no signal, and a CI gate against drift. It is the route for a machine where git is not already the transport, or for a third party, and that is its reopening condition.
- **`npx skills add hebstr/skills`**: see `DESIGN-AGENT-SKILLS.md`, section "The `skills` CLI lands in `~/.agents/skills` whatever agent is named, measured 2026-11-08".
- **Copying the seven bodies into the `claude` stow package**: breaks the reco's rule of one `SKILL.md` with no duplicated prose.

Open on purpose: the clone's freshness on `cpd` depends on a pull that nothing triggers, which is the same posture `DESIGN-CPD.md` § "Open points" already records for the dotfiles clone itself.

Applied the same day in `8047880`, on `ju-TP`: the two `skills.paths` entries, the `external_directory` allow above, and the records. The clone on `cpd` and the four measurements it gates are owed on that machine.

A standing coupling the change leaves behind: the `showboat verify` check of `_meta/notes/opencode-harness-setup.md` that prints `jq -c "{model, instructions, permission: (.permission | keys), skills}"` pins the `skills` object verbatim, so any later edit to `skills.paths` makes that expected output false and has to carry it.

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

`external_directory` set to `allow` on `~/.claude/**`, on the link farm and, since 2026-11-08, on `~/Documents/packages/skills/**`, the skills clone the section "The seven skills of `hebstr/skills` leave the farm for the clone, 2026-11-08" adds; skill directories are already allowed by opencode itself, but this block opens on `"*": "ask"` and the farm carries its own allow, so a `templates/` or `scripts/` read under the clone would have been auto-rejected under `opencode run` without it.

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

The 8 KB that priced the rejection has since been passed, `AGENTS.md` having gained rules of its own, and what the rejection rests on is accumulation rather than byte count.
Its budget half has decayed, measured 2026-09-30: `~/.claude/CLAUDE.md` was 12,104 bytes against the 57,521 of `b70a9c7` that priced the design, and the memory index 20,661 against 50,732, so the digest weighed 71 % of the file it exists to keep out of the prompt, about 0.9k tokens of an 18.4k fixed part.
What has not decayed is the other half, the Claude-only instructions that mislead a small model, which `_meta/notes/zotero-agent-access-reco.md` gives evidence for: its "Where to look for more" wording is a candidate cause for the 9B never calling its own `skill` tool, so whether a hand-maintained digest still earns its drift risk is open.

Why the guard protects two roots rather than one: every file under `~/.claude` that matters resolves into `~/dotfiles/claude/.claude` through stow, and `AGENTS.md` itself tells the model to edit the resolved path of a symlink, so a refusal on `~/.claude` alone would have been bypassed by following the rules.

## The hooks plugin translates the payload and reports back to the model, 2026-09-21

`opencode/.config/opencode/plugins/claude-hooks.ts`, stowed the same day, pinned by `_meta/tests/claude-hooks-plugin.bats`, which drives the plugin through `node` against stub hook scripts under a fake `HOME`.

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

## Next, in the order agreed on 2026-09-21

1. The user's first interactive trial, in `~/Documents/services/md-nesrine` on a throwaway branch, following `.claude/ESSAI-OPENCODE.md` in that project (untracked there): the model's knowledge of the project rules without being shown them, `/design` as a slash command, a multi-step task with the gate, a hook refusal, a long session through compaction.
   Its results come back in a fresh conversation through the prompt at the end of that note.
2. Then the adversarial reviews, held back so that they do not review a version the trial could still change.
   Still pending: `/audit:blindspot claude/.claude/memory/project_opencode_agents_md_mirror.md`, and a second walkthrough of `claude-hooks.ts` only if the trial changes the plugin.
3. Then, depending on what the trial shows: the farm freshness check deferred in `DEFERRED.md`, and the A/B against Gemma 4 12B set out in `DESIGN-GPU-REMOTE.md` § "The choice survives a second search, 2026-09-21".
   The `bash` allowlist was the third item here and did not wait for the trial: the user hit the prompts in real use on `cpd`, so it was widened on 2026-11-05 (see "The read allowlist widened, 2026-11-05").

## Open points

- Whether a skill set to `ask` stays usable as a slash command when the user types it: needs the interactive TUI, item 1 of "Next".
- A command on the `bash` allowlist can still write without a redirection if the tool itself writes (`ruff check --fix`, `shfmt -w`, `air format` on any path given): accepted, since these are the gate the model is told to run, but they are not confined to the project.
- The skill farm is resynced only by `claude-plugins-update`, so a plugin auto-update or a `/plugin enable|disable|update` done in Claude Code leaves opencode on the superseded version, or on a disabled plugin's skills, until the next `sys-update`, breaking in the meantime the rule that only an enabled plugin's skills are ever exposed.
  Deferred with a chosen remedy in `DEFERRED.md`, row of 2026-09-21 on the opencode skill farm, whose scope narrowed on 2026-11-08 to the third-party plugin skills: the seven of `hebstr/skills` left the farm, and with it the `enabledPlugins` rule, which the section "The seven skills of `hebstr/skills` leave the farm for the clone, 2026-11-08" accepts losing for them.
