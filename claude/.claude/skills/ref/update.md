# Update: `/ref --check` and `/ref --update`

This file describes the freshness audit and update flow for `ref` notes.
Routed from `SKILL.md` when the user invokes `/ref --check ...` or `/ref --update ...`.

## What it does

Each note under `quarto/` and `biostat/` carries a YAML front-matter `sources:` list. Every entry has a `kind:` (`repo` or `blog`) and metadata sufficient to detect upstream changes:

```yaml
sources:
  - kind: repo
    repo: owner/name        # GitHub slug
    url: https://github.com/owner/name
    ref: vX.Y.Z | <sha7>    # tag or 7-char commit SHA captured at write time
    captured: YYYY-MM-DD
    files:                   # repo-relative paths whose content has been inlined or referenced
      - path/to/file.yml
  - kind: blog
    url: https://...         # canonical post URL OR documentation site landing page
    published: YYYY-MM-DD    # OPTIONAL — set only for dated posts. Omit for living sites
                             # (pkgdown sites, doc landing pages, ongoing guides) where
                             # there is no single publication date.
    captured: YYYY-MM-DD     # required
```

`--check` reads every note's front-matter, fetches upstream signals, and produces a freshness report. `--update` does the same, then for stale entries proposes diffs to the note body and offers to bump the metadata after user validation.

## Modes

### `/ref --check [filter]`

Audit only. No edits. The filter argument, if present, restricts to a domain or note (e.g. `quarto`, `quarto canouil`, `biostat heiss-bayes`). Without a filter, audit all notes.

For each `sources[]` entry:

- **`kind: repo`**:
  1. Fetch `https://api.github.com/repos/<repo>` to confirm the repo still exists and find the default branch.
  2. Resolve `ref` against current HEAD:
     - If `ref` is a tag: fetch `releases/latest` and compare tag names.
     - If `ref` is a 7-char SHA: fetch `commits/<default-branch>` to get the latest SHA on the default branch (call it `<HEAD-sha>`). Compare to the stored SHA. Use `gh api repos/<repo>/compare/<ref>...<HEAD-sha> --jq .ahead_by` for a commit-distance number. (`<HEAD>` here means the SHA of the latest commit on the default branch returned by the previous step, not a literal string.)
  3. For each `files[]` path: HEAD `https://raw.githubusercontent.com/<repo>/<HEAD>/<path>`. Status 200 = present, 404 = missing/renamed/deleted.

- **`kind: blog`**:
  1. Fetch the URL. Status 200 = alive; 404/410 = gone; 3xx redirect = note where it now points.
  2. Heuristic freshness: look for an explicit "Updated" / "Last updated" / `<meta property="article:modified_time">` / dateline in the rendered page; compare to `captured:` (and `published:` if set). If nothing parseable is found, report **unknown freshness**. When `published:` is omitted (living site), skip the "publication-date drift" check and only test URL liveness + last-modified heuristic.

Output a single markdown rapport with one section per note and one row per source:

```markdown
## Rapport de fraîcheur (2026-04-25)

### quarto/canouil-extensions
- [FRESH]   mcanouil/quarto-code-window @ v1.1.5 — current latest

### quarto/heiss-extensions
- [STALE]   andrewheiss/quarto-output-styling @ 59a4945 — 8 commits behind HEAD
- [BROKEN]  andrewheiss/quarto-wordcount/_extensions/wordcount/words.lua — 404 (renamed?)
- [FRESH]   andrewheiss/fancy-epigraphs-quarto @ b21f5d6 — current HEAD

### quarto/heiss-snippets
- [UNKNOWN] blog post 2023-12-11 — alive, no Last-Modified parsed
```

Status codes: `FRESH` (matches stored ref), `STALE` (newer commit/release), `BROKEN` (404 on file or repo), `UNKNOWN` (blog with no parseable date), `MOVED` (3xx redirect target ≠ stored URL), `GONE` (410, account deleted).

`--check` stops here. The user reads the rapport and decides whether to run `--update` next.

### `/ref --update [filter]`

Runs `--check` first, then for each non-FRESH source proposes a fix, fiche by fiche, validating with the user before applying.

Per stale source:

1. **Fetch upstream context.**
   - `repo` → fetch each `files[]` at HEAD (or new path if `BROKEN` and clearly renamed). For tagged repos, also fetch the new release notes (`gh api repos/<repo>/releases/latest --jq .body`).
   - `blog` → fetch the URL and extract the rendered text body.
2. **Diff against the note body.** Locate the blocks in the note that came from this source: when a note has several sources, attribute by repo/URL mention in the surrounding prose, or by the `Source:` line at the bottom of each section. If a block cannot be confidently attributed to a single source, **do not propose an edit for that block**; surface the ambiguity to the user instead.

   In the attributed blocks, look for what objectively changed upstream:
   - Version bumps in YAML headers (`version: 1.1.5` → `1.2.0`).
   - New options or arguments documented upstream.
   - Removed/renamed options.
   - File renames or removals.
   - For blogs: substantive factual updates (a new paragraph, a fix, a deprecation note).

   What **not** to propose:
   - Editorial rewording (a tighter sentence upstream → don't rewrite the note's prose).
   - Stylistic reflows of code blocks that produce the same semantics.
   - Reordering of options that have no behavior change.

   When in doubt, surface the upstream change to the user with no proposed edit and let them decide.
3. **Present a per-fiche change summary** (not a raw diff) plus a proposed Edit block:

   ```
   quarto/heiss-extensions — andrewheiss/quarto-output-styling
   Upstream changed:
   - Added option `output-styling.padding` (default 1em) — _extension.yml line 12.
   - `output-styling-default.css` renamed to `output-styling-base.css`.

   Proposed edits to the note:
   1. Update SHA: 59a4945 → <new-sha7>, captured: 2026-04-25 → <today>.
   2. In the "Verbatim usage" block, add `padding: 1em` example.
   3. In the resources list, rename `output-styling-default.css` → `output-styling-base.css`.

   Apply? [y/skip/abort]
   ```
4. **On `y`**: apply Edits for this fiche, including the metadata bump (`ref:` and `captured:`).
5. **On `skip`**: move to the next fiche without applying. Leave the entry's `captured:` unchanged so a later run still flags it.
6. **On `abort`**: stop, leave already-applied fiches as is.

### `--batch` flag

`/ref --update --batch [filter]` skips the per-fiche prompt and applies all proposed edits without confirmation. Not the default.

`--batch` is **refused** (fall back to per-fiche confirmation, even if the user passed `--batch`) when the `--check` pass returned any of:

- `BROKEN`, `MOVED`, or `GONE` on any source: these require human judgement.
- A major version bump in a `kind: repo` source (e.g. `v1.x` → `v2.x`, or any tag where the leading SemVer major changed): breaking changes likely, content overhaul not safe to auto-apply.
- A file rename in `files:` (a stored path no longer exists at HEAD but a near-named file does): path-renaming is never inferred automatically, so surface it to the user.

`--batch` is only safe when every proposed edit is a metadata bump (`ref:`, `captured:`) or a same-shape content update (option added, option default changed) on a `STALE` or `UNKNOWN` source. Anything else falls back to per-fiche confirmation.

## What `--update` does NOT do

- It does not rewrite editorial framing. The notes are curated: Claude proposes content updates that map to upstream changes, never restructures the note's pedagogy.
- It does not auto-fix `BROKEN` sources by guessing the new path. If a file 404s, surface it to the user; let them decide whether the note should be edited, the path corrected, or the source dropped.
- It does not touch `catalog.md` automatically. If a note's topic has shifted enough to need a new catalog line, flag it but ask the user.

## Implementation notes

- Use `gh api` (already authenticated, invoked via the `Bash` tool declared in `SKILL.md`) for GitHub queries. Use `WebFetch` for blog URLs and `raw.githubusercontent.com` (gh CLI doesn't fetch raw content).
- Run all source checks for a single fiche in parallel (one `gh api` and `WebFetch` per source).
- For repos with many `files[]` entries, batch-check files in parallel.
- Network failure modes: on `5xx`, timeout, DNS failure, or malformed response, mark the source `UNKNOWN` for this run and surface the error to the user, never silently skip. On GitHub `403` rate-limit, stop the run and tell the user (don't retry-loop).
- For blog HTML parsing: prefer `<meta property="article:modified_time">` → `<time datetime="...">` near the top of the page → first dateline in the body. If none found, status `UNKNOWN`, not `STALE`.
- Today's date comes from the harness (`Today's date is YYYY-MM-DD` in context). Use it for `captured:` bumps.
- Filter argument matching: enumerate notes via `Glob` on the skill root (`<domain>/*.md` for a domain filter, `<domain>/<author>-*.md` for a domain+author filter, exact path for an explicit fiche). Do not derive the file list from `catalog.md`: `Glob` is the source of truth on disk, and `catalog.md` is a human-facing index that may lag.
- Examples: `quarto` matches all notes under `quarto/`; `quarto canouil` matches `quarto/canouil-*.md`; `quarto canouil-extensions` is the explicit fiche.
