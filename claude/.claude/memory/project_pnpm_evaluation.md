---
name: pnpm evaluated and rejected against the npm footprint of dotfiles
description: pnpm not adopted 2026-10-24; the npm footprint was measured and npm 12 ships the two transferable arguments, analysis done from docs and registry, do not redo it
metadata:
  type: project
---

pnpm was evaluated on 2026-10-24 against the actual npm footprint of this machine and not adopted. Nothing was installed: the verdict rests on local measurement plus pnpm, npm, Node and stylelint official docs.

The footprint is four manifests, all tooling, no workspace and no JS application:

- `~/.local/share/css-gate/` (stow package `css`): prettier, stylelint, stylelint-config-standard-scss pinned exact, `package-lock.json` v3 tracked, `node_modules/` ignored, config beside its own `node_modules` so `extends` resolves from there
- `bin/.local/bin/css-toolchain-update`: wraps `npm install --save-exact`; 69 lines across three bats files cite `npm`, including a full `npm` stub in `css-toolchain-update.bats`
- `sys-update` and `sys-cleanup`: `npm update -g`, `npm cache verify`
- `~/.npmrc` (machine-local, never stowed): `prefix=~/.npm-global`, `allow-scripts=opencode-ai`; one global package, `opencode-ai`
- `quarto-hebstr-doc`: repo-local install, `npm ci` in `render.yml`, two prek hooks on `node_modules/.bin/`

Four measurements that decide it:

- **The disk gain is marginal.** pnpm dedups by hardlink across projects, and the two toolchain trees (30 MB each) are not on the same versions, so only part of the transitive set would link. The large posts are elsewhere: 1.4 GB in `~/.npm/_cacache` and 410 MB of global package.
- **The strictness gain is already acquired.** `stylelint-config-recommended-scss` declares `stylelint-scss` and `postcss-scss` as real `dependencies`, and `postcss` is a dependency of `stylelint` itself. None of the 112 packages npm hoists to the gate's root is reached by phantom resolution, so pnpm's isolated layout would find nothing.
- **npm 12 ships both transferable arguments.** npm 12.2.1 (2026-10-15, `node ^22.22.2 || ^24.15.0 || >=26.0.0`) documents `install-strategy=linked` ("install in node_modules/.store, link in place, unhoisted") and recommends it to catch phantom dependencies, and npm 12.0.0 blocks dependency lifecycle scripts by default behind an `allowScripts` policy.
- **The premise is population-dependent.** Stack Overflow Developer Survey 2025, n = 24,473: npm 56.8%, Yarn 21.1%, pnpm 13.4%. State of JS 2025 monorepo tools: pnpm 3,940 responses against npm Workspaces 2,129. pnpm leads among monorepo users and trails badly in the general population; this footprint is the second case.

Two upstream facts worth keeping. pnpm's own docs concede the layout breaks tools (`publicHoistPattern`, default `[]`: "useful when dealing with some flawed pluggable tools that don't resolve dependencies properly"), and pnpm#8378 removed `*eslint*` and `*prettier*` from its defaults in October 2024, after which prettier 3.5.3 was reported as finding no plugin at all without the pattern put back. And pnpm cut two majors in four months (11.0.0 on 2026-04-28, 12.0.0 on 2026-08-26, a Rust rewrite), dropping `onlyBuiltDependencies` in 11, against an npm that arrives with Node from apt and does not move.

Revisit trigger: a real monorepo or multi-package Node project, which is the one population where the evidence supports pnpm. Decide it per project then, without touching the gate.

**Why:** "pnpm is the current standard" is true enough in JS app development that it reads as settled, and it inverts once the question is scoped to a config with one private toolchain. Re-asking it without re-measuring the plugin declaration chain and re-checking npm's current feature set would repeat a full session for the same answer.
**How to apply:** Do not propose migrating the CSS gate, `css-toolchain-update`, the `sys-update` / `sys-cleanup` npm modules or `~/.npmrc` to pnpm. If strictness is ever wanted on this chain, the lever is npm's own `install-strategy=linked`, tested first because npm 12 also makes unknown `.npmrc` keys throw and stops honouring `npm-shrinkwrap.json`, and because `npm install -g npm@12` under the user prefix would shadow the apt-managed npm that `rules/install.md` assumes. Corepack is end of life for this purpose: Node's v24 docs state it is removed from Node v25 onward, and pnpm 12's install page no longer mentions it, so the `corepack 0.36.0` on this machine is a vestige.
