/design port the opencode harness to V2: `claude-hooks.ts` to the V2 plugin API, then the shared `opencode.json` to the native V2 shape

## What this conversation inherits

A V2 diagnostic was run on `cpd` on 2026-11-10 against the official docs, reviewed and corrected on `ju-TP` on 2026-11-11. The corrected state is below.

Where things stand on 2026-11-11, from the user:

- `cpd` runs V2, and opencode is paused there until `claude-hooks.ts` is rebuilt, the user having confirmed the V1 plugin does not load.
- `ju-TP` carries both as this is written. V2 2.2.7 was installed there on 2026-11-11 at `~/.opencode/bin/opencode`, with the `opencode2` shim beside it and the stow symlink `opencode-serve` intact. V1 1.19.5 still answers `opencode` by name, `~/.opencode/bin` not being on the `PATH`, so V2 is reached by its absolute path until that changes and nothing about the working setup moved. **This conversation runs on `ju-TP`**, and the port is written and tested here because `ju-TP` has node 24.22.2 and bats 1.10.0 while `cpd`'s toolchain for the suite is unknown. Confirm every version rather than trusting this line.
- Both machines migrate, and converting the config to the native V2 shape is in scope rather than deferred.

Three things have to be true on this machine before anything is proposed, and each is the user's to do rather than yours:

1. V2 reachable as `opencode`, which is the half of the install still open: `~/.opencode/bin` put on the `PATH` by `bash/.profile`, on the model of the `~/.npm-global/bin` block already there, and `npm uninstall -g opencode-ai` to retire V1. Until both are done V2 answers by absolute path alone, which carries every probe below and no real session.
2. The runtime dependency of the new import resolvable from `~/.config/opencode`, whose `package.json` pins `@opencode-ai/plugin` at 1.18.31 and whose `node_modules` carries the V1 scope `@opencode-ai` (`plugin` and `sdk`) and no `@opencode` scope at all, measured 2026-11-11. That file is machine-local and the repository does not track it, so the step exists once per machine and nothing records it yet.
3. `~/.claude/**` flipped from `allow` to `ask` in the `external_directory` block, or opencode not driven here beyond the probes, for as long as the port has not landed. The reason is under "Do not".

Then measure the three decision zones of the plugin section here, in session, instead of reading anyone's file: that is what moving this work to `ju-TP` buys. Readings taken on `cpd` before the pause are not reachable from here and are no substitute.

## The ordering constraint that governs everything

V2 reads a V1 config: "V2 reads existing system, global, and project configuration from the same locations as V1", "V2 normalizes supported V1 and native V2 fields in memory without rewriting the source file", "you do not need to convert it to try or adopt V2" (https://opencode.ai/docs/migrate-v1). Unsupported legacy fields and conflicting V1/V2 values produce warnings while the rest keeps loading. The official order is: install, keep the config, verify, port the plugins, then convert, "This step is optional".

The compat runs one way only. The same page warns "do not point V1 at files after converting them to native V2-only shapes", and `opencode/.config/opencode/opencode.json` is a single stow source shared by `cpd` and `ju-TP` through git. **The config conversion stays last, after both machines run V2.** Converting it while either machine still runs 1.19.5 breaks that machine's permission layer. `cpd` is already past that point, so `ju-TP`'s own install is the only thing still gating it.

The plugin is the hard blocker, and it is what gates `cpd` coming back: V1 plugin implementations do not run in V2 at all, so between a machine's V2 install and the port, `prose-lint-pretool.sh`, `format-on-edit.sh` and the `PROFILE_ROOTS` guard are all off there.

## Blocker: porting `claude-hooks.ts`

Mappings, all verified against https://opencode.ai/docs/build/plugins/migrate-v1:

- Import `@opencode-ai/plugin` becomes `@opencode/plugin`; the named export becomes a default `Plugin.define({id, setup(ctx)})`. The comment in `claude-hooks.ts` about opencode calling every export of the module stops being true. The import also changes in kind: `import type` is erased at runtime, where `Plugin.define(...)` is a value, so the package has to resolve when the module is loaded, by opencode and by the test driver alike. That is prerequisite 2 of the opening section, and it is a new failure mode for a file that needed no runtime dependency until now.
- `directory` comes from `ctx.location.directory`.
- `experimental.chat.system.transform` becomes `ctx.session.hook("context", ...)` editing `event.system`. **Resolved**: `event.system` is an array of content parts, the doc's own example pushing `{ type: "text", text: "..." }`. `stripGlobalProfile` currently maps over strings, so the port maps over `.text`. The reconstruction it does (`Instructions from: <file>\n<content>`) still has to be checked against what V2 actually writes into those parts: a changed format strips nothing, silently.
- `tool.execute.before` and `tool.execute.after` become `ctx.tool.hook("execute.before"|"execute.after", ...)`. The signature `(input, output)` becomes one mutable `event`, with `event.tool` and `event.input`.

Three decision zones, none of them mechanical:

1. **Does throwing from a hook still refuse the call?** `tool.execute.before` currently throws an `Error` to block, and that single mechanism carries both the `PROFILE_ROOTS` guard (opencode must not modify `~/.claude` or the stow source of the Claude Code profile) and the exit-2 block from `prose-lint-pretool.sh`. The V2 docs do not document it. This is a guard rather than a convenience, so if throwing no longer blocks, the guard has to be rebuilt elsewhere (`ctx.permission.hook("evaluate", ...)` is the candidate to measure) before V2 is used for anything but the trial.
2. **Can a hook still rewrite a tool's output?** `tool.execute.after` appends the `format-on-edit.sh` report to `output.output` so the model reads it. The migration page lists the hook but documents neither the event's fields nor output rewriting. `DESIGN-OPENCODE-HARNESS.md`, section "The hooks plugin translates the payload and reports back to the model, 2026-09-21", records that this report is the reason the PostToolUse hook exists. If the mechanism is gone, choose another way to surface the report or drop it, explicitly.
3. **Are the tool names still `edit` and `write`?** `EDIT_TOOLS` gates both hooks on those two names. V2 renames the permission actions `write` and `patch` to `edit`; whether the tool names followed is unverified and decides whether `EDIT_TOOLS` still has two members.

The port is a substantial rewrite of the file, so `rules/code.md` applies to its output: the dozen WHY comments `claude-hooks.ts` carries today (the fuzzy-match rationale, the detached process group, the EPIPE guard, the relative-`instructions` walk) move into `DESIGN-OPENCODE-HARNESS.md`. Several are measurements no other file holds.

`_meta/tests/claude-hooks-plugin.bats` drives the plugin through node against stub scripts under a fake HOME, its driver loading the module with `await import(plugin)` and destructuring the named `ClaudeHooks` export. Both halves break on the port: the export becomes a default, and the value import above has to resolve from wherever the driver runs. The suite follows the plugin and is not invented separately, and it is the gate this port leaves green, which is the reason the work sits on `ju-TP`. It is also the instrument that settles the three zones below rather than a formality: it ran 34 tests, all passing, on 2026-11-11 before any port, and it already pins each of the three contracts, the refusal by `throw` in its `guard:` tests, the appended report in `after: the hook's report is appended to the tool output`, and the strip in its `system:` tests. A zone that V2 cannot honour shows up as those tests failing, which is the measurement.

## To convert, last, once both machines run V2

**V2 already computes this conversion, and prints it.** Measured on `ju-TP` with 2.2.7 on 2026-11-11: `~/.opencode/bin/opencode debug config` exits 0 with an empty stderr, no warning of any kind, and prints the normalized document, where `permission` has become an ordered `permissions` array of 131 rules (105 `shell`, 22 `skill`, 4 `external_directory`), `provider` has become `providers`, and `skills.paths` has become an array. So the native file is not hand-derived from the rules below: start from that output, and use the rules to judge what it produced and what it left alone. Nothing in the V1 file was reported as ignored or conflicting.

`permission` becomes `permissions`, an ordered array of `{action, resource, effect}`, last match winning (https://opencode.ai/docs/permissions). Facts that bear on the conversion:

- `bash` becomes `shell`. Also renamed, though unused in this config: `task` to `subagent`, `write` and `patch` to `edit`.
- The default with no matching rule is `ask`, and when an operation checks several resources "any `deny` denies the operation; otherwise any `ask` asks; otherwise the operation is allowed". The leading `"*": "ask"` therefore becomes redundant with the default; keeping it first is harmless, dropping it changes nothing.
- Only `*` and `?` are documented as wildcards, `*` matching `/` included, and the pattern matches the whole normalized value. The `**` of the `external_directory` block was expected to go, but the compat layer passes its four rules through verbatim, `/tmp/**` and `~/.claude/**` included (measured 2026-11-11). Either `**` still matches or those rules match nothing, and the second reading would mean `~/.claude/**` is already inert today. Measure it in session before rewriting them, since it also decides how exposed the window of the "Do not" entry really is.
- A shell pattern ending in ` *` also matches the bare command, so `git status *` covers `git status`. Some `ask`/`deny` entries written as bare substrings under V1 change coverage under this rule.
- Resources are produced by the V2 shell scanner, which extracts each subcommand of a compound command and tests them separately, checks `cd` targets, and returns a scanner error rather than executing what it cannot analyse. The connector allowlist (`;*`, `&&*`, `|*`, `2>&1*`, `>&*`) becomes pointless, and `"*>*": "ask"` loses its object since redirections are no longer part of the resource.
- `skill` keeps its name.

Other keys:

- `skills`: the object `{paths: [...]}` becomes one ordered array of paths and URLs (https://opencode.ai/docs/skills). **Resolved**: `~/.claude/skills` is auto-discovered in V2 under "Global compatibility", so it leaves the list. Precedence runs from built-ins up, `.claude/skills` low and explicit `skills` entries highest, so the clone's seven skills cannot be masked by the compat source. Dropping the entry is a choice rather than something compat did: the normalized array measured on 2026-11-11 still carries `~/.claude/skills` verbatim, alongside the two clone paths. `debug skill` is gone in V2, so confirming resolution takes a session rather than one command. Keep in mind that the two clone entries are deliberately dead on `ju-TP`, an accepted trade recorded in `DESIGN-OPENCODE-HARNESS.md`, section "The seven skills of `hebstr/skills` leave the farm for the clone, 2026-11-08".
- `provider` becomes `providers`, `"options": {baseURL}` becomes `"settings": {baseURL}`, and `models` with their `limit` carry over unchanged (measured). The `package` value has two candidate forms and the choice is the design's: the Providers page gives `"@opencode/ai/providers/openai-compatible"` for a declaration written from scratch (https://opencode.ai/docs/providers), while the compat layer maps the V1 `"npm": "@ai-sdk/openai-compatible"` to `"package": "aisdk:@ai-sdk/openai-compatible"`, keeping the original package behind an `aisdk:` prefix. Both providers of this config normalize to the second form today. Decide on evidence that the chosen one serves the llama.cpp endpoints, not on which reads better.
- `tui.json` becomes a single global `~/.config/opencode/cli.json`, schema `https://opencode.ai/v2/cli.json`, `theme` an object with `name` and `mode`, `attention` keeping `notifications` and `sound` and losing `enabled` (https://opencode.ai/docs/cli/config). **Mostly automatic**: "the first V2 terminal client startup migrates supported global `tui.json` settings and persisted preferences while leaving V1 files unchanged". Treat it as a verification, and decide what the stow package keeps once the real `cli.json` exists.
- Not impacted: `AGENTS.md`, `instructions`, `model`, `watcher.ignore`, `~/.opencode/bin/opencode-serve`.

## Installing V2, per machine

The installer (https://opencode.ai/v2/install) is a bash script that puts the binary in `$HOME/.opencode/bin`, creates an `opencode2` shim beside it, overwrites an existing `opencode` there without uninstalling anything, and edits a shell config file to add the directory to `PATH` unless `--no-modify-path` is passed. V1 and V2 "both use the `opencode` command and are no longer installed side by side by default".

- `cpd`: **done on 2026-11-11**, and opencode is paused there pending this port. What never came back here is whether the stow symlink `~/.opencode/bin/opencode-serve` survived, the installer writing into that same directory: check it when `cpd` resumes.
- `ju-TP`: **the binary landed on 2026-11-11, the switchover did not.** The installer ran with `--no-modify-path`, deliberately: the shell rc files are stow symlinks into this repository, and an installer edit would land through the symlink instead of through a reviewed change. Nothing therefore puts `~/.opencode/bin` on the `PATH` yet, and V1 from npm (`~/.npm-global/bin/opencode`, prefix set in `_meta/notes/dotfiles-bootstrap.md`) still answers `opencode`. Two steps remain, both the user's: the `PATH` entry in `bash/.profile`, and `npm uninstall -g opencode-ai`, which the docs require so that two binaries do not sit on the `PATH` with their order deciding which runs.
- `OPENCODE_SERVER_USERNAME` is no longer supported, the username always being `opencode`. Check `opencode-serve` and anything that talks to the server API.

## Tracking files this migration must update

- `_meta/notes/opencode-cpd-setup.md` asserts "opencode 1.19.5 runs from `~/.opencode/bin/opencode`", a live claim the V2 install invalidates. It also still carries the open step about restowing `opencode` on `cpd` after the `opencode-serve` rename.
- `_meta/notes/opencode-harness-setup.md` carries the install step `npm install -g opencode-ai`, which stops being the route.
- The update routine changes on `ju-TP`: `sys-update` covers opencode through `npm update -g`, and a curl install leaves npm's reach. Decide the replacement route against `reference_tool_update_routines.md` and `rules/install.md`, section "One entry point: `sys-update`".
- `DESIGN-OPENCODE-HARNESS.md` is the note that owns the decision and receives it, in English, with absolute dates, plus the WHY comments the plugin rewrite evicts.

## Do not

- Do not convert the config before both machines run V2. The constraint is the one-way compat quoted above, not a preference. `cpd` is already there, `ju-TP` is not until its own install.
- Do not leave `~/.claude/**` on `allow` in `external_directory` while `ju-TP` runs V2 without the ported plugin. On `cpd` that window is harmless, Claude Code never being installed there. On `ju-TP` the path is the live profile, the `PROFILE_ROOTS` guard that protects it lives in the plugin alone, and the config allows writes there so that skills stay readable. Flip the entry to `ask` for the window, or do not drive opencode here beyond the probes.
- Do not treat the plugin port as a translation: the three decision zones each need an explicit, recorded choice.
- Do not rewrite the shell allowlist without revalidating the residues accepted on 2026-11-05, recorded in `DESIGN-OPENCODE-HARNESS.md`, section "The read allowlist widened, 2026-11-05". They were measured against V1 matching (tree-sitter, full source text of the command), and the V2 scanner changes the rules. The take-backs `sort*-o*`, `tree*-o*` and `sed*-i*` and the git `deny` rules are the part to re-measure first, the git ones being in substring form since 2026-11-08 because the V1 scanner rewrote `cd X && git push` as `git -C X push`.
- Do not fold in the "Next" openings `DESIGN-OPENCODE-HARNESS.md` carries (interactive trial, adversarial reviews). They predate this migration and are not part of it.

## Ground truth

- Current config: `cat ~/dotfiles/opencode/.config/opencode/opencode.json`, `cat ~/dotfiles/opencode/.config/opencode/tui.json`
- Current plugin: `~/dotfiles/opencode/.config/opencode/plugins/claude-hooks.ts`, 152 lines
- Local V2 state: `~/.opencode/bin/opencode --version`, `ls -l ~/.opencode/bin/`. The V2 `debug` namespace holds `agents`, `config`, `heap-dump` and `paths` (`debug --help`, 2.2.7, 2026-11-11): `debug skill` is gone, so skill resolution has no CLI route in V2 and is checked from inside a session or through `debug agents`
- The compat translation of the current config: `~/.opencode/bin/opencode debug config`, which prints the normalized document and is the starting point for the native file
- Plugin dependency state: `cat ~/.config/opencode/package.json`, `ls ~/.config/opencode/node_modules/`
- The gate: `bats _meta/tests/claude-hooks-plugin.bats`, green before the port and green after
- Reference note to read whole before proposing anything: `~/dotfiles/.claude/DESIGN-OPENCODE-HARNESS.md`, 271 lines, which holds the decisions and measurements that constrain the port
- V2 docs: https://opencode.ai/docs/migrate-v1, https://opencode.ai/docs/build/plugins/migrate-v1, https://opencode.ai/docs/permissions, https://opencode.ai/docs/config, https://opencode.ai/docs/providers, https://opencode.ai/docs/skills, https://opencode.ai/docs/cli/config
