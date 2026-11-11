/design port the opencode harness to V2: `claude-hooks.ts` to the V2 plugin API, then the shared `opencode.json` to the native V2 shape

## What this conversation inherits

A V2 diagnostic was run on `cpd` on 2026-11-10 against the official docs, reviewed and corrected on `ju-TP` on 2026-11-11. The corrected state is below. The user decided on 2026-11-11 that both machines migrate, `cpd` first then `ju-TP`, and that converting the config to the native V2 shape is in scope rather than deferred.

Before this conversation opens, the user runs the V2 install and the compat readings on `cpd` by hand. **Ask for those readings first**: the warnings V2 emits on the unconverted config, `opencode debug config`, `opencode debug skill`, and whether the shell scanner accepts the real allowlist. Several items below are written as open precisely because those readings answer them, and nothing should be proposed before they are in hand.

## The ordering constraint that governs everything

V2 reads a V1 config: "V2 reads existing system, global, and project configuration from the same locations as V1", "V2 normalizes supported V1 and native V2 fields in memory without rewriting the source file", "you do not need to convert it to try or adopt V2" (https://opencode.ai/docs/migrate-v1). Unsupported legacy fields and conflicting V1/V2 values produce warnings while the rest keeps loading. The official order is: install, keep the config, verify, port the plugins, then convert, "This step is optional".

The compat runs one way only. The same page warns "do not point V1 at files after converting them to native V2-only shapes", and `opencode/.config/opencode/opencode.json` is a single stow source shared by `cpd` and `ju-TP` through git. **The config conversion is therefore the last step, after both machines run V2.** Converting it while either machine still runs 1.19.5 breaks that machine's permission layer.

The plugin is the only hard blocker: V1 plugin implementations do not run in V2 at all, so between the V2 install and the port, `prose-lint-pretool.sh`, `format-on-edit.sh` and the `PROFILE_ROOTS` guard are all off on that machine.

## Blocker: porting `claude-hooks.ts`

Mappings, all verified against https://opencode.ai/docs/build/plugins/migrate-v1:

- Import `@opencode-ai/plugin` becomes `@opencode/plugin`; the named export becomes a default `Plugin.define({id, setup(ctx)})`. The comment in `claude-hooks.ts` about opencode calling every export of the module stops being true.
- `directory` comes from `ctx.location.directory`.
- `experimental.chat.system.transform` becomes `ctx.session.hook("context", ...)` editing `event.system`. **Resolved**: `event.system` is an array of content parts, the doc's own example pushing `{ type: "text", text: "..." }`. `stripGlobalProfile` currently maps over strings, so the port maps over `.text`. The reconstruction it does (`Instructions from: <file>\n<content>`) still has to be checked against what V2 actually writes into those parts: a changed format strips nothing, silently.
- `tool.execute.before` and `tool.execute.after` become `ctx.tool.hook("execute.before"|"execute.after", ...)`. The signature `(input, output)` becomes one mutable `event`, with `event.tool` and `event.input`.

Three decision zones, none of them mechanical:

1. **Does throwing from a hook still refuse the call?** `tool.execute.before` currently throws an `Error` to block, and that single mechanism carries both the `PROFILE_ROOTS` guard (opencode must not modify `~/.claude` or the stow source of the Claude Code profile) and the exit-2 block from `prose-lint-pretool.sh`. The V2 docs do not document it. This is a guard rather than a convenience, so if throwing no longer blocks, the guard has to be rebuilt elsewhere (`ctx.permission.hook("evaluate", ...)` is the candidate to measure) before V2 is used for anything but the trial.
2. **Can a hook still rewrite a tool's output?** `tool.execute.after` appends the `format-on-edit.sh` report to `output.output` so the model reads it. The migration page lists the hook but documents neither the event's fields nor output rewriting. `DESIGN-OPENCODE-HARNESS.md`, section "The hooks plugin translates the payload and reports back to the model, 2026-09-21", records that this report is the reason the PostToolUse hook exists. If the mechanism is gone, choose another way to surface the report or drop it, explicitly.
3. **Are the tool names still `edit` and `write`?** `EDIT_TOOLS` gates both hooks on those two names. V2 renames the permission actions `write` and `patch` to `edit`; whether the tool names followed is unverified and decides whether `EDIT_TOOLS` still has two members.

The port is a substantial rewrite of the file, so `rules/code.md` applies to its output: the dozen WHY comments `claude-hooks.ts` carries today (the fuzzy-match rationale, the detached process group, the EPIPE guard, the relative-`instructions` walk) move into `DESIGN-OPENCODE-HARNESS.md`. Several are measurements no other file holds.

`_meta/tests/claude-hooks-plugin.bats` drives the plugin through node against stub scripts under a fake HOME. It follows the plugin and is not invented separately.

## To convert, last, once both machines run V2

`permission` becomes `permissions`, an ordered array of `{action, resource, effect}`, last match winning (https://opencode.ai/docs/permissions). Facts that bear on the conversion:

- `bash` becomes `shell`. Also renamed, though unused in this config: `task` to `subagent`, `write` and `patch` to `edit`.
- The default with no matching rule is `ask`, and when an operation checks several resources "any `deny` denies the operation; otherwise any `ask` asks; otherwise the operation is allowed". The leading `"*": "ask"` therefore becomes redundant with the default; keeping it first is harmless, dropping it changes nothing.
- Only `*` and `?` are wildcards, `*` matching `/` included, and the pattern matches the whole normalized value. The `**` of the `external_directory` block has to go.
- A shell pattern ending in ` *` also matches the bare command, so `git status *` covers `git status`. Some `ask`/`deny` entries written as bare substrings under V1 change coverage under this rule.
- Resources are produced by the V2 shell scanner, which extracts each subcommand of a compound command and tests them separately, checks `cd` targets, and returns a scanner error rather than executing what it cannot analyse. The connector allowlist (`;*`, `&&*`, `|*`, `2>&1*`, `>&*`) becomes pointless, and `"*>*": "ask"` loses its object since redirections are no longer part of the resource.
- `skill` keeps its name.

Other keys:

- `skills`: the object `{paths: [...]}` becomes one ordered array of paths and URLs (https://opencode.ai/docs/skills). **Resolved**: `~/.claude/skills` is auto-discovered in V2 under "Global compatibility", so it leaves the list. Precedence runs from built-ins up, `.claude/skills` low and explicit `skills` entries highest, so the clone's seven skills cannot be masked by the compat source; `opencode debug skill` on the trial confirms it in one command. Keep in mind that the two clone entries are deliberately dead on `ju-TP`, an accepted trade recorded in `DESIGN-OPENCODE-HARNESS.md`, section "The seven skills of `hebstr/skills` leave the farm for the clone, 2026-11-08".
- `provider` becomes `providers`, and each entry changes shape: `"npm": "@ai-sdk/openai-compatible"` becomes `"package": "@opencode/ai/providers/openai-compatible"`, and `"options": {baseURL}` becomes `"settings": {baseURL}` (https://opencode.ai/docs/providers). `models` and their `limit` carry over.
- `tui.json` becomes a single global `~/.config/opencode/cli.json`, schema `https://opencode.ai/v2/cli.json`, `theme` an object with `name` and `mode`, `attention` keeping `notifications` and `sound` and losing `enabled` (https://opencode.ai/docs/cli/config). **Mostly automatic**: "the first V2 terminal client startup migrates supported global `tui.json` settings and persisted preferences while leaving V1 files unchanged". Treat it as a verification, and decide what the stow package keeps once the real `cli.json` exists.
- Not impacted: `AGENTS.md`, `instructions`, `model`, `watcher.ignore`, `~/.opencode/bin/opencode-serve`.

## Installing V2, per machine

The installer (https://opencode.ai/v2/install) is a bash script that puts the binary in `$HOME/.opencode/bin`, creates an `opencode2` shim beside it, overwrites an existing `opencode` there without uninstalling anything, and edits a shell config file to add the directory to `PATH` unless `--no-modify-path` is passed. V1 and V2 "both use the `opencode` command and are no longer installed side by side by default".

- `cpd`: V1 already runs from `~/.opencode/bin/opencode`, so the installer overwrites it in place. Pass `--no-modify-path`, the directory being on `PATH` already, and check afterwards that the stow symlink `~/.opencode/bin/opencode-serve` survived.
- `ju-TP`: V1 comes from npm (`~/.npm-global/bin/opencode`, prefix set in `_meta/notes/dotfiles-bootstrap.md`). The docs require removing a package-managed V1 first, otherwise two binaries sit on `PATH` and the order decides which runs. Pass `--no-modify-path` there too: the shell rc files are stow symlinks into this repository, and an installer edit would land through the symlink.
- `OPENCODE_SERVER_USERNAME` is no longer supported, the username always being `opencode`. Check `opencode-serve` and anything that talks to the server API.

## Tracking files this migration must update

- `_meta/notes/opencode-cpd-setup.md` asserts "opencode 1.19.5 runs from `~/.opencode/bin/opencode`", a live claim the V2 install invalidates. It also still carries the open step about restowing `opencode` on `cpd` after the `opencode-serve` rename.
- `_meta/notes/opencode-harness-setup.md` carries the install step `npm install -g opencode-ai`, which stops being the route.
- The update routine changes on `ju-TP`: `sys-update` covers opencode through `npm update -g`, and a curl install leaves npm's reach. Decide the replacement route against `reference_tool_update_routines.md` and `rules/install.md`, section "One entry point: `sys-update`".
- `DESIGN-OPENCODE-HARNESS.md` is the note that owns the decision and receives it, in English, with absolute dates, plus the WHY comments the plugin rewrite evicts.

## Do not

- Do not convert the config before both machines run V2. The constraint is the one-way compat quoted above, not a preference.
- Do not treat the plugin port as a translation: the three decision zones each need an explicit, recorded choice.
- Do not rewrite the shell allowlist without revalidating the residues accepted on 2026-11-05, recorded in `DESIGN-OPENCODE-HARNESS.md`, section "The read allowlist widened, 2026-11-05". They were measured against V1 matching (tree-sitter, full source text of the command), and the V2 scanner changes the rules. The take-backs `sort*-o*`, `tree*-o*` and `sed*-i*` and the git `deny` rules are the part to re-measure first, the git ones being in substring form since 2026-11-08 because the V1 scanner rewrote `cd X && git push` as `git -C X push`.
- Do not fold in the "Next" openings `DESIGN-OPENCODE-HARNESS.md` carries (interactive trial, adversarial reviews). They predate this migration and are not part of it.

## Ground truth

- Current config: `cat ~/dotfiles/opencode/.config/opencode/opencode.json`, `cat ~/dotfiles/opencode/.config/opencode/tui.json`
- Current plugin: `~/dotfiles/opencode/.config/opencode/plugins/claude-hooks.ts`, 152 lines
- Reference note to read whole before proposing anything: `~/dotfiles/.claude/DESIGN-OPENCODE-HARNESS.md`, 271 lines, which holds the decisions and measurements that constrain the port
- V2 docs: https://opencode.ai/docs/migrate-v1, https://opencode.ai/docs/build/plugins/migrate-v1, https://opencode.ai/docs/permissions, https://opencode.ai/docs/config, https://opencode.ai/docs/providers, https://opencode.ai/docs/skills, https://opencode.ai/docs/cli/config
