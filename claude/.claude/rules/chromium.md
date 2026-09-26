---
paths:
  - "**/.claude/rules/chromium.md"
---

# Headless browser and verification captures

Injected by `inject-rules.sh` on a `chromium` or `firefox` command.

## Chromium is the only reachable browser

- `/snap/bin/chromium`, kept current by `sys-update snap`. Firefox is installed but cannot start under the agent's sandbox, which denies the namespace it needs (`unshare(CLONE_NEWPID): EPERM`), and then misreports the failure as "Firefox is already running" whatever profile or `-no-remote` flag is passed.
- Computed styles are read with `--headless=new --dump-dom` over a probe page calling `getComputedStyle`, which settles a CSS specificity dispute that a screenshot cannot; `--screenshot` captures the page.
- Snap confinement keeps two places out of reach: the session scratchpad under `/tmp`, where `--screenshot` fails with a misleading `Failed to write file ... No such file or directory`, and the dot-directories directly under `$HOME`. A project's own `.claude/` is reachable, read and written alike. Every capture and every probe page therefore goes in the project.
- Every headless launch takes its own throwaway profile, created and removed in the same shell call that ends the browser: `P=$(mktemp -d ~/snap/chromium/common/claude-profile.XXXXXX); trap 'rm -rf "$P"' EXIT`, then `--user-data-dir="$P"`. Without `--user-data-dir`, a run killed before it exits leaves a `scoped_dir*` profile of up to about 146 MiB under `~/snap/chromium/common/chromium-headless/`; a fixed shared profile makes a concurrent launch abort with exit 21 on its `SingletonLock`.
- Chromium ships no hyphenation dictionary, so `hyphens: auto` measures identical to `hyphens: none` here: read that as "not measurable locally", never as "the property is inert".

## Where verification captures go

- A binary verification artefact goes in `<project>/.claude/screenshots/`, never in the scratchpad, never under `~/snap/` or any other system directory: a headless browser capture, a `pdftoppm` page, a rasterized LibreOffice render. It is the evidence that a verification happened, so it belongs beside the plan that cites it and stays inspectable in the next session.
- Check that `.claude/` is git-ignored before writing, and ignore it otherwise: a capture is never versioned.
- The scope is what you open and read. A purely intermediate file you never look at (a DOM probe, a throwaway HTML page) stays in the scratchpad when the tool can write there, which chromium cannot.
