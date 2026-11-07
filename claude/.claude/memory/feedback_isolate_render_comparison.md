---
name: Isolate a before/after render comparison from every other change, peer sessions included
description: "A pixel or output comparison is only valid when the two renders differ by the change under test alone: a concurrent session writing the same tree invalidates it silently, and a throwaway `git worktree` at HEAD carrying only the files under test is the fix. Noise floor is a property of the browser profile: one profile gives 0 differing pixels, two give tens."
metadata:
  type: feedback
---

A before/after comparison of a rendered artefact (a pixel diff of a page, a diff of generated HTML or of a produced document) proves something only when the two renders differ by the change under test and nothing else. Before trusting one, establish that: read `git status` for edits that are not yours, and run `ListAgents` when the project is one several sessions touch.

When anything else is moving in the tree, do not try to subtract it. Build the comparison in a throwaway worktree instead:

```sh
git worktree add --detach <sibling-dir> HEAD     # then copy in only the files under test
# ... render, capture, compare ...
git worktree remove --force <sibling-dir>
```

Reconstruct each file under test from `HEAD` plus your own edits rather than copying the working-tree version, which carries the other session's work too. The worktree goes outside the project, a nested checkout confusing both repositories; binary evidence still goes to the project's own `.claude/screenshots/`, per `rules/chromium.md`.

**Why:** measured in `quarto-hebstr-doc` on 2026-11-07. A CSS selector change was compared against a baseline captured minutes earlier, and the diff came back at 1 130 112 differing pixels of 25 200 000 instead of the few thousand the change could explain. The cause was a peer session landing a vendored Python syntax definition in the same tree between the two renders: `def` was tokenised `kw` in one capture and `im` in the other, and a dozen downstream blocks shifted by 51 px. Nothing about the comparison said so; it read as a catastrophic regression of the change under test. Redone in a worktree at `HEAD` carrying the two edited stylesheets alone, the same change measured 2 336 differing pixels, all inside the one element it touches.

Two corollaries from the same pass:

- **The rasteriser noise floor is a property of the browser profile, not of the renderer.** Two captures of one unchanged page taken in the same `--user-data-dir` differ by **0** pixels, where two taken in separate throwaway profiles differ by tens (66 and 77 on that page, max channel delta 2, in one thin band). So measure the floor the way you will measure the change, and prefer one profile for both captures: a floor of 0 turns "within the noise" into an exact claim.
- **Normalise before diffing generated HTML, then read the whole diff.** Replacing every `base64,...` payload with a placeholder makes the structural diff readable, but printing only its first lines misled this pass into concluding "only the gt table ids differ" when the token spans differed further down. Count the diff and read all of it, or grep it for the element in question.

Relates to [[feedback_browser_layout_probe]], [[feedback_verify_before_claiming]], [[feedback_commit_sequence_add_all]].
