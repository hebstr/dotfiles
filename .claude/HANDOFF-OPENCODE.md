# Audit the claude-hooks plugin change of 2026-11-11, a Claude Code session

## State at the time of writing

Commit `752f70f` on `main` of `~/dotfiles` ("fix(opencode): load the hooks plugin through Plugin.define") holds four files:

- `opencode/.config/opencode/plugins/claude-hooks.ts`: the type-only import became a value import, `import { Plugin } from "@opencode/plugin"`, and the default export is now `Plugin.define({ id, setup })` instead of a plain object.
- `_meta/tests/claude-hooks-plugin.bats`: the driver registers a module resolve hook (`node:module` `register`) that maps `@opencode/plugin` to an identity `define` stub before importing the plugin.
- `.claude/DESIGN-OPENCODE-HARNESS.md`, section "The ported plugin carries no runtime dependency, 2026-11-11": rewritten to record what the measurement found.
- this brief itself, `.claude/HANDOFF-OPENCODE.md`.

The commit is local on ju-TP and not pushed: `origin/main` sits at its parent, so a push of `main` carries it.

## Why the change exists

The plain `{ id, setup }` default export did not load under the opencode 2.2.7 server: a probe under a scratch `XDG_CONFIG_HOME` failed with `SchemaError(Missing key at ["default"])`. The host demands the marked form even though `Plugin.define` is an identity in `@opencode/plugin@2.2.7`.
The value import works because the 2.2.7 binary serves `@opencode/plugin` from its embedded cache; nothing is installed on disk.
This reverses the earlier decision of the same section, which had rejected the `Plugin.define` call to avoid a runtime dependency and a 190 MB `node_modules` tree.

## What to audit

1. **The measurement.** Reproduce it if possible: under a scratch `XDG_CONFIG_HOME`, start an opencode 2.2.7 server with this plugin configured, and check the log for "loading plugin" with no failure.
   Confirm the plain-object export really fails with the schema error on this binary, so the note's claim is not a one-off.
2. **The driver stub.** The bats resolve hook maps `@opencode/plugin` to `export const Plugin = { define: (p) => p }`.
   Judge whether that faithfully stands in for the real package for what the suite exercises: the suite imports the plugin and calls `setup`, so it never sees a schema check on the default export.
   The one behaviour the stub cannot catch is a host-side schema change, which only the live probe of point 1 covers. Say whether that gap is acceptable.
3. **The note.** Read `.claude/DESIGN-OPENCODE-HARNESS.md`, section "The ported plugin carries no runtime dependency, 2026-11-11", against what the files actually do.
   Flag any claim that does not match the code or that a later reader would have to re-measure.

## Ground truth for each step

- `bats _meta/tests/claude-hooks-plugin.bats` from `~/dotfiles`: 42 tests, all green at the time of writing.
- The plugin loads under node v22.23.4 with a resolver stub (same shape as the bats one); without any stub it fails module resolution, which is expected on this machine and not a defect: the consumer is the opencode server, not bare node.
- `git show --stat 752f70f` in `~/dotfiles` lists exactly those four files, and `git status --short` is empty: nothing else is modified.

## Bounds and traps

- Do not install `@opencode/plugin` anywhere to make the audit easier. The whole point of the change is that no disk installation exists; installing it would test a configuration the user does not run.
- Do not revert the import to type-only while auditing. That form is what failed to load, and reverting it mid-audit changes the object under review.
- The opencode server probe needs a scratch `XDG_CONFIG_HOME` pointing at a config that lists this plugin, so the real `~/.config/opencode` is never touched.

## What is owed elsewhere

Nothing in this audit should be folded into other notes: the section above is the record, and its "Weakest assumption" paragraph already names the failure mode of a version that stops serving the package from its embedded cache.

## Where the record goes

Write the outcome as a new dated section under `.claude/DESIGN-OPENCODE-HARNESS.md`, after the section being audited, following the note's existing form: what was measured, what it established, and the weakest assumption left open.
That file is whitelisted in `.claude/.gitignore` and tracked by the parent repository; no other note takes this outcome.
