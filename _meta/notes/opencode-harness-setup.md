# opencode harness on ju-TP against Qwen3.5 9B on ju-TP2

*2026-09-21T15:11:45Z by Showboat 0.6.1*
<!-- showboat-id: 0d0d568d-ec9e-4b4b-bb0d-964238ec741c -->

How to rebuild, from this repository, the local coding agent set up on 2026-09-21: opencode runs on `ju-TP`, inference runs on `ju-TP2`'s GPU through an SSH forward, and opencode reads the Claude Code profile (`~/.claude`) through a harness. The why, the measurements and the rejected ways live in two design notes, `.claude/DESIGN-GPU-REMOTE.md` and `.claude/DESIGN-OPENCODE-HARNESS.md`. `.claude/` is gitignored, so those notes exist only on the machines Syncthing reaches: this trace is the part a fresh clone carries.

What the setup is made of, all tracked:

- `bin/.local/bin/llama-session`: brings up one inference session, starting `llama-server` on `ju-TP2` if none runs, forwarding its port to `127.0.0.1:8080`, tearing both down on exit. Defaults to `unsloth/Qwen3.5-9B-GGUF`, file `Qwen3.5-9B-UD-Q5_K_XL.gguf`, context 98304, and downloads the model with `hf` when absent.
- `bin/.local/bin/llama-update`: installs the llama.cpp CUDA build on `ju-TP2`.
- `opencode/.config/opencode/opencode.json`: the `ju-tp2` provider and the 9B with its `limit`, `instructions` loading each project's `.claude/CLAUDE.md` and `.claude/memory/MEMORY.md` (found by walking up to the git root), `skills.paths` pointing at the link farm, and `permission` (`bash` on ask outside a read-and-gate allowlist, `external_directory` open on `~/.claude`, `skill` denying the MCP-bound and claude.ai skills and gating the user-invoked ones).
- `opencode/.config/opencode/AGENTS.md`: the behavioral rules of `CLAUDE.md` that any agent can apply, including reading a project's `.claude/PLAN.md` at session start, and pointers into `~/.claude/rules/`. Its presence stops opencode from loading `~/.claude/CLAUDE.md` whole.
- `opencode/.config/opencode/plugins/claude-hooks.ts`: refuses any `edit` or `write` resolving under `~/.claude` or `~/dotfiles/claude/.claude`, runs the Claude Code hooks `prose-lint-pretool.sh` and `format-on-edit.sh` around the others (refusing an `edit` of an existing `.md`, `.qmd` or `.Rmd` whose `oldString` is not verbatim, which the pre-hook could not replay), and strips the global profile from the system prompt when opencode runs outside a git repository, where the `instructions` walk climbs to `~/.claude`, or inside `~/dotfiles/claude`, where it finds the profile's stow source.
- `bin/.local/bin/opencode-skills-sync`: links every skill of the enabled Claude Code plugins into `~/.local/share/opencode-claude-skills/`; `claude-plugins-update` reruns it, so `sys-update claude-plugins` keeps it current for the updates it makes itself.

## GPU host, `ju-TP2`

Two traces cover it and are not repeated here: `_meta/notes/llama-cuda-install-ju-tp2.md` (the CUDA build, and the proof that the GPU is used) and `_meta/notes/llama-update-deploy-ju-tp2.md` (`llama-update`, then `stow --no-folding bin` there). The `hf` CLI comes from `uv tool install huggingface-hub`, a manual step on a fresh machine (README, "Bootstrap"). No model needs fetching by hand: `llama-session` downloads its default on first start, about 6.3 GiB.

## Agent host, `ju-TP`

Recorded after the fact on 2026-09-21: opencode was installed earlier that day, the two packages stowed and the link farm first built later the same day, none of it traced when run. These steps change state, so they sit in tilde fences with the state they left, and `verify` never replays them.

Install opencode under the user npm prefix (README, "Bootstrap", sets it), which `sys-update npm` then keeps current:

~~~bash
npm install -g opencode-ai
npm ls -g --depth=0 opencode-ai
~~~

~~~text
└── opencode-ai@1.18.31
~~~

Link the scripts and the configuration. Both packages are part of the README's `stow` line; on a machine already stowed, only the files added since need linking:

~~~bash
cd ~/dotfiles && stow --no-folding bin opencode
~~~

~~~text
opencode.json -> ../../dotfiles/opencode/.config/opencode/opencode.json
AGENTS.md -> ../../dotfiles/opencode/.config/opencode/AGENTS.md
plugins/claude-hooks.ts -> ../../../dotfiles/opencode/.config/opencode/plugins/claude-hooks.ts
~/.local/bin/opencode-skills-sync -> ../../dotfiles/bin/.local/bin/opencode-skills-sync
~~~

Build the plugin-skill link farm once. `claude-plugins-update` reruns it after the updates it makes, but on a fresh machine the farm does not exist until this first run, and opencode then sees no plugin skill. A plugin changed outside `claude-plugins-update` (Claude Code's auto-update, `/plugin enable`, `disable` or `update`) leaves the farm stale until the next `sys-update` or a manual run, a gap tracked in `.claude/DEFERRED.md`:

~~~bash
opencode-skills-sync
~~~

~~~text
Linked 73 plugin skill(s) into /home/julien/.local/share/opencode-claude-skills
~~~

opencode creates `~/.config/opencode/package.json`, its `node_modules` and a `.gitignore` itself on first start, to load plugins: nothing to do there.

## A session

Needs the remote host up, so not replayed:

~~~bash
llama-session          # terminal 1: holds the session, Ctrl-C tears it down
opencode               # terminal 2, from the project directory
~~~

A command outside the `bash` allowlist, or one carrying a redirection, asks for approval in the TUI; under `opencode run` such a request is rejected. The live checks of 2026-09-21 on the 9B (budget, skill filtering, plugin, permissions) are recorded in `.claude/DESIGN-GPU-REMOTE.md` step 10 and `.claude/DESIGN-OPENCODE-HARNESS.md`.

## Checks

These read only what characterises the setup, never versions, counts of plugin skills or timestamps, so they keep passing until the setup itself breaks.

```bash
for f in opencode.json AGENTS.md plugins/claude-hooks.ts; do readlink -e ~/.config/opencode/$f; done; readlink -e ~/.local/bin/opencode-skills-sync ~/.local/bin/llama-session
```

```output
/home/julien/dotfiles/opencode/.config/opencode/opencode.json
/home/julien/dotfiles/opencode/.config/opencode/AGENTS.md
/home/julien/dotfiles/opencode/.config/opencode/plugins/claude-hooks.ts
/home/julien/dotfiles/bin/.local/bin/opencode-skills-sync
/home/julien/dotfiles/bin/.local/bin/llama-session
```

```bash
opencode-skills-sync >/dev/null && test -d ~/.local/share/opencode-claude-skills/r-lib/cli && echo "link farm built"
```

```output
link farm built
```

```bash
f=$(mktemp); (cd /tmp && opencode debug skill >"$f" 2>/dev/null); jq -r "[.[] | select(.name == \"cli\" or .name == \"cadrer\" or .name == \"ooo\") | .name] | sort | join(\" \")" "$f"; rm -f "$f"
```

```output
cadrer cli ooo
```

```bash
(cd /tmp && opencode debug agent build 2>/dev/null) | jq -c "[.permission[] | select(.permission == \"bash\")] | [first.pattern, first.action, last.pattern, last.action]"
```

```output
["*","ask","*>*","ask"]
```

```bash
jq -c "{model, instructions, permission: (.permission | keys), skills}" opencode/.config/opencode/opencode.json
```

```output
{"model":"ju-tp2/qwen3.5-9b","instructions":[".claude/CLAUDE.md",".claude/memory/MEMORY.md"],"permission":["bash","external_directory","skill"],"skills":{"paths":["~/.local/share/opencode-claude-skills"]}}
```

```bash
bats _meta/tests/opencode-skills-sync.bats _meta/tests/claude-hooks-plugin.bats _meta/tests/llama-session.bats _meta/tests/claude-plugins-update.bats >/dev/null && echo "suites pass"
```

```output
suites pass
```

What each check proves, in order: the configuration and scripts resolve into this repository; the link farm builds and holds a known plugin skill; opencode discovers a skill of each origin (`cli` from a plugin through the farm, `cadrer` from `~/.claude/skills`, `ooo` from a plugin, listed although denied, since `debug skill` ignores permissions); `bash` opens and closes on `ask`; the configuration names the 9B, loads each project's `.claude/` files, carries no inert `edit` block and points `skills.paths` at the farm; the four bats suites behind the setup pass, the plugin's covering the profile guard, the hooks and the removal of the global profile outside git. `opencode debug skill` is read from a file, not a pipe: piped, its output comes out truncated.

