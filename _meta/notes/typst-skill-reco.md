# typst skill: does `lucifer1004/claude-skill-typst` enter the harness as the Typst knowledge base?

2026-10-17. Decision asked: does this third-party Claude Code skill enter the harness as the Typst knowledge base?

The verdict rests on the upstream tree read through `gh api`, a bare clone measured in the session scratchpad and deleted, and probes run against the Typst already on this machine.
The install came after the verdict, on the user's instruction the same day; its trace is in "The adopt branch" below.

## Restating the question

Three questions whose answers can diverge:

- Does the skill enter under the convention of `.claude/DESIGN-AGENT-SKILLS.md` § "Third-party skills go through the `agents` package and its lock"?
- Is there a Typst knowledge gap on this machine worth filling at all?
- If there is, does this skill's content fill it?

Done means one answer per question, a revisit trigger that can be recognised when it lands, and a revert path.

Out of scope: the `typst-review` reviewer skill that would sit on top, which got its own `/design` pass the same day and whose decision is in `~/dotfiles/.claude/DESIGN-TYPST-REVIEW.md`; and any change to how Quarto renders Typst here.

## The tool

Read 2026-10-17 at `main`, pushed 2026-10-12.

```
| Fact                   | Value                                                            |
|------------------------|------------------------------------------------------------------|
| Licence                | MIT                                                              |
| Created                | 2026-01-24                                                       |
| Stars / watchers       | 132 / 0                                                          |
| Human contributors     | 2 (`lucifer1004` 46 commits, `CarloLucibello` 1)                 |
| Bot commits            | 40 (`github-actions[bot]`)                                       |
| Last human commit      | 2026-09-03                                                       |
| Releases / milestones  | none / 0                                                         |
| Tags                   | one, `typst-0.14.2`, so only a SHA can be pinned                 |
| Open issues / PRs      | `#1` Renovate config, `#3` a docs correction open since 2026-09-15 |
```

The skill proper is `skills/typst/`: `SKILL.md` (8,360 bytes), 14 reference files (97 KB of markdown in all), two agent definitions, 7 top-level `.typ` examples plus a package example, 4 Python scripts, and `data/` holding 10 JSON indexes.
The last ten commits are the weekly bot (`data: update package index`, `data: update API indexes`).

Three counts in the brief that launched this pass do not hold: there are 14 reference files rather than 20, 4 bundled scripts rather than one, and `SKILL.md` invokes two of them.

## Protocol

Corpus, chosen independently of the tool: every `.typ` and every `.qmd` reachable under `~/Documents`, `~/admin` and `~/dotfiles`, plus the harness files the adoption would touch.

```
| Measurement                     | How                                                                 |
|---------------------------------|---------------------------------------------------------------------|
| Reach on the real corpus        | `fdfind -e typ`, deduplicated by `md5sum`; `rg -l '\{=typst\}'`     |
| Content accuracy                | 12 checkable claims of `migration.md` and `debug.md` run through `typst eval` and `typst compile` on the installed 0.15.1 |
| Storage cost                    | `git archive` of two upstream snapshots 4 weeks apart, `git add` into a throwaway repository, `du` on `.git/objects` |
| Commit-gate collision           | the hooks of `~/dotfiles/prek.toml` against the file sizes of `skills/typst/data` |
| Update behaviour                | the currency check of `bin/.local/bin/agent-skills-update` against `agents/.agents/.skill-lock.json` |
```

Installed here, resolved rather than recalled: `typst` 0.15.1 at `/snap/bin/typst`, `typstyle` 0.15.2 at `~/.cargo/bin/typstyle`, `quarto` 1.10.19, `pdftotext`, `jq`, `python3` 3.12.3.
Every dependency the skill declares is satisfied, and the installed compiler is the exact version its stable index targets.

## Results

### Reach on this machine's corpus: thin today, and ruled out of the question

The string `quarto` appears zero times across the skill's 14 reference files, its `SKILL.md`, its two agent definitions and its examples.
`conversion.md` converts from LaTeX and Markdown, not from Quarto.

The user ruled on 2026-10-17 that this does not decide: the skill is for `.typ` files, those exist, and a knowledge base is not judged on one project's current state.
What the corpus still establishes is the size of the bet, and it is smaller than it looks:

- 41 `.typ` files on disk reduce to 17 distinct by content, and all but one are vendored copies of a Quarto extension template or sit under an `_extensions.bak` directory.
- One hand-authored standalone file exists, `~/admin/pro-cv/cv-body.typ`, 224 lines, last edited 2026-10-16.
- Three `{=typst}` blocks across two live documents, `pro-cv/cv.qmd` and `pro-ordo/ordo.qmd`.
- 5 of 332 `.qmd` carry a `typst:` format key.
- `hebstr-doc`, the extension every other document project installs, declares itself "A multi-format Quarto theme (HTML, DOCX)". It shipped a typstyle-formatted `template.typ` until commit `34e7003`, "feat: drop the Typst output format", on 2026-09-29.
- `quarto-hebstr-book`, `quarto-hebstr-slide` and `quarto-cell-options` carry zero `.typ`.
- `hebstr-template`, the user's own extension (`author: hebstr`, version 0.9.0), is the one real Typst template suite: 8 tracked `.typ` under `_extensions/hebstr-template/resources/typst/` in `claude-code-litrev`, up to 8,272 bytes for `definitions.typ`, untouched since 2026-04-05.

So the hand-authored `.typ` surface is `pro-cv/cv-body.typ`, active, plus a dormant template suite, with the main extension's Typst format removed three weeks ago.

The boundary the skill cannot see stays worth recording even though it does not decide: it is the one `rules/typst.md` devotes its first section to, and the one `~/admin/pro-cv/.claude/DESIGN-TYPST-LAYOUT.md` was written on 2026-10-16 to settle. A `{=typst}` chunk is invisible to typstyle, tinymist and `typst compile`, the native `#bibliography()` loses the author list where citeproc keeps it, and `--font-path` is required of every standalone step because only the front matter declares it.
None of those facts is in the skill, and none could be: it knows standalone Typst.

### Content accuracy: good, with two defects that fail loudly

11 of 12 sampled claims verified against the installed 0.15.1.
`pattern`, `pdf.embed` and `json.decode` are gone; `curve`, `tiling`, `pdf.attach`, `divider` and the `path` type exist; `list.marker-align` defaults to `end`; the CLI has `eval --in` and no `query` subcommand.

Two defects, both in text an agent would paste:

- `migration.md` offers `query(heading.within(<appendix>))` as the new 0.15 selector. It errors with "function `heading` does not contain field `within`". `selector(heading).within(<appendix>)` and `heading.where(level: 1).within(<appendix>)` both compile.
- The symbol table of `debug.md` says `times.circle` has no working name and tells the reader to paste a literal glyph. `typst eval 'sym.times.o'` returns ⊗ and `sym.times.o.big` returns ⨂, the `.o` modifier being general (`sym.plus.o` returns ⊕). The other two rows of that table are correct.

The second defect has a correction open upstream as PR #3 since 2026-09-15, from the project's only outside contributor, with no comment and no merge 32 days later, while the bot has committed six times.

### Scripts and supply chain: clean, and reachable with no local edit

`search-api.py` and `search-packages.py` import the standard library only and resolve `data/` through `os.path.dirname(os.path.abspath(__file__))`, so they run from any working directory.
The single `subprocess.run` call executes `typst --version`. No network call, no write outside stdout.

`SKILL.md` invokes them as `python3 scripts/search-api.py`, a relative path that resolves against the project working directory.
That is not a defect to patch: Claude Code prefixes every skill load with `Base directory for this skill: <path>`, observed in this session on `poc`, which is itself a symlinked directory under `~/.claude/skills/`, the exact shape the installer would create for `typst`.
The absolute base is therefore in hand whenever the skill fires, and the relative invocation is resolvable without touching the vendored tree.

### Weight in the dotfiles repository: about seven times cheaper than feared

The working tree is 9.4 MB, of which `data/` is 9.2 MB, and `api.json` is byte-identical to `api-0.15.1.json` (same blob SHA), as is `api-bm25.json` to `api-0.15.1-bm25.json`.

Compressed as git objects, with no delta compression, one snapshot costs 1.4 MB.
Adding a second snapshot four upstream weeks older brings the total to 2.0 MB, so four weeks of drift cost 0.6 MB before packing.
The upstream repository's entire nine-month history, 839 objects and some forty weekly regenerations, packs to 4.44 MiB.
The dotfiles pack is 2.89 MiB today.

So the initial cost is roughly half the current pack again, and the recurring cost is of the order of 150 KB per update actually run, which is an upper bound.
The 9.5 MB figure describes the checkout, never the history.

### The commit gate stops it, and one exclusion lifts it

`prek.toml` carries `check-added-large-files` with `--maxkb=500` and no exclusion, where `shellharden`, `prose-lint`, `panache-format`, `pyrefly-check`, `ruff-check`, `ruff-format`, `shellcheck` and `shfmt` all exempt `^agents/`.

9 of the 10 files in `skills/typst/data` exceed 500 KB, from `packages.json` at 574 KB to `api-main.json` at 2,062 KB; only `packages-bm25.json` at 364 KB passes, the hook listing the nine when run directly with `--enforce-all`.
`prek run check-added-large-files --all-files` is green on an unstaged tree and proves nothing: the hook reads `git diff --staged --diff-filter=A`, so it sees the files only once they are added to the index, which is the commit itself.
The remedy is the exclusion the eight other hooks already carry, and its cost is named rather than hidden: every future vendored skill then escapes the large-file guard, which is the only hook standing between this repository and a dependency that ships a model or a dataset.
The guard keeps its bite everywhere a file is written by hand.

### A local adaptation would not survive, and none is wanted

`agent-skills-update` compares each lock entry's `skillFolderHash` with the upstream tree SHA and never hashes the local directory, so a local prune of the 5.9 MB of indexes this machine cannot use (`api-0.15.0*`, `api-main*`, and the two duplicates of `api*`) passes the currency check unnoticed.
It is also undone without a prompt: `skills update -g` reinstalls a changed skill by replacing its directory wholesale, and the weekly bot commit to `skills/typst/data` changes the tree SHA on its own.
The same holds for a local `paths:` or `disable-model-invocation` in the frontmatter.

This constrains nothing here, since the point of vendoring through the lock is to take upstream as it comes: no edit is wanted, so none is lost.
What it does rule out is the pruning option, so the 9.4 MB is taken whole or not at all.

### Auto-triggering: a smaller cost than the brief prices

The frontmatter carries `name` and a 283-character `description`, with no `paths` and no `disable-model-invocation`, so the model decides when it fires.
What sits in every session is that description; the 8,360-byte body and the reference files load only on a trigger.

The surface it would fire on is almost exactly the surface where it is wanted: 5 `.qmd` of 332, plus one `.typ` project.
The real hazard is not volume, it is that on four of those five `.qmd` the skill's own Compilation and verification recipes are the wrong procedure, and it carries nothing that would tell it so.

## Decision

The pass first concluded against adoption on three grounds. The user overturned two as scope rulings on 2026-10-17, and the third was a claim this pass had asserted without checking it. Both states are recorded here because the reasoning is what a later session needs.

**It enters, under the convention of `.claude/DESIGN-AGENT-SKILLS.md`.** What is left after the three are resolved is a one-line prek exclusion and about 1.4 MB of git objects, against a 0.15.1 API index matching the installed compiler exactly, a weekly-refreshed Typst Universe package index, and 97 KB of reference prose measured accurate on 11 of 12 sampled claims.

The three grounds, and what became of each:

- *Zero Quarto coverage.* Ruled out of the question by the user: the skill targets `.typ`, those exist here, and a knowledge base is not judged on one project's current state. The corpus measurement stands as recorded above and is a statement of how thin the bet is, not a blocker.
- *The commit gate.* Accepted as a cost. The `^agents/` exclusion the eight other hooks already carry lifts it, and what that widens is named under Results.
- *Local edits erased weekly.* Wrong as stated. It rested on `SKILL.md` invoking its scripts by a relative path, which this pass treated as needing a local patch without first checking how a skill is loaded. Claude Code prefixes every skill load with its base directory, observed in this session on `poc`, a symlinked directory under `~/.claude/skills/` of exactly the shape the installer creates. No edit is needed, so none is lost to the weekly reinstall.

**The accuracy reservation is not a blocker and is not dismissed either.** The data indexes are bot-maintained and stay current; the prose is human-maintained and the human has been dormant since 2026-09-03, with the only outside correction open as PR #3 for 32 days. The prose is what the model reads first, and it is the half that ages.

**Nothing else is built.** A `ref` note for a `typst` domain is premature: the 0.15 API questions this pass raised were each settled in seconds by `typst eval` against the installed compiler, which is the authority the skill's index copies.

### Usage warning

The indexes and the prose disagree, and the index is right.
`search-api.py --name sym.times.o -v` returns ⊗ against a `debug.md` that tells the reader no such name exists, which is the defect of PR #3.
Where a reference file and the data disagree, the data wins; where the data and `typst eval` disagree, the compiler wins.

Revisit trigger, for dropping it rather than for reopening it: a second content defect found in use after the one in `debug.md`, with PR #3 still unmerged, which would establish that the prose half is unmaintained rather than merely slow.

Revert path:

```sh
npx -y skills remove typst -g -y
rm -rf ~/dotfiles/agents/.agents/skills/typst ~/.claude/skills/typst
```

Then drop the skill's entry from `agents/.agents/.skill-lock.json` if the CLI left it, and revert the `check-added-large-files` exclusion.

## The adopt branch

Run on 2026-10-17.

- **Install**, the form `agent-skills-update` prints in its repair line, with two target agents because a single one makes the CLI copy instead of symlink: `npx -y skills add lucifer1004/claude-skill-typst -g -s typst -a claude-code cline -y`. It wrote `agents/.agents/skills/typst/` (9.4 MB, git-tracked and Syncthing-replicated to ju-TP2), the lock entry at `skillFolderHash` `2f516a2b5ab8aee855319562b3711c662d4f0270`, and the per-machine symlink `~/.claude/skills/typst -> ../../.agents/skills/typst`, which git never tracks. No hook, no `settings.json` key, no MCP server: the fourteen hooks across seven events are untouched. The CLI printed its own risk assessment row (Socket 0 alerts, Snyk low), which is the vendor's claim and not a reading of the tree.
- **`check-added-large-files`** in `prek.toml` took `exclude = '^agents/'` in the same pass, or nine of the ten `data/*.json` would be refused at the commit.
- **Updater**: covered, no new script. `sys-update --list` carries the `agent-skills` module, and `agent-skills-update` ran clean after the install, reporting both lock entries current upstream.

Smoke-tested the same day, from `~/admin/pro-cv` rather than from the skill directory, so the relative invocation of `SKILL.md` was exercised against a real project cwd: `search-api.py --name sym.times.o -v`, a BM25 query, `--list-categories`, and `search-packages.py --category cv`, which filters against the installed 0.15.1 it detects by running `typst --version`.
Claude Code discovered the skill without a restart, as the base-directory reasoning above predicted.

## What stays uncovered

- The accuracy sample is 12 claims from 2 of the 14 reference files. `tables.md`, `academic.md`, `styling.md`, `query.md`, `advanced.md`, `package.md` and `perf.md` were not checked, and the two defects found were both in the sampled pair, so the error rate elsewhere is unknown.
- The quality of the API index itself, as opposed to the prose, was not measured: no query was run through `search-api.py`, the pass having read the scripts rather than executed them. The first real lookups after the install are what will show whether the index answers better than `typst eval`.
- Whether the model would have got those 11 verified facts right without the skill was not measured, so the gain the content represents over no skill at all is unquantified.
- The two agent definitions, `agents/typst-verify.md` and `agents/typst-package-qa.md`, were read for size only.
- `typst-review`, the reviewer skill the brief defers, is untouched by this verdict. What it would need, a Quarto-aware reading of a rendered artifact, is precisely what this candidate lacks. Designed on 2026-10-17 in `~/dotfiles/.claude/DESIGN-TYPST-REVIEW.md`, which keeps the two agent definitions out of its own scope for the reason recorded there: `agents/typst-verify.md` is not a `SKILL.md`, so no reviewer scan can select it.
