---
name: Tools Claude launches leave residue when a timeout kills them
description: A process Claude starts from the Bash tool and that gets killed (timeout, torn-down CDP session) skips its own cleanup; give every such tool a throwaway state dir removed by an EXIT trap in the same call, and suspect Claude's own recipes when a residue grows fast
metadata:
  type: feedback
---

When a tool launched from the Bash tool creates temporary state and may end by being killed rather than exiting, that state is never cleaned: the kill skips the tool's own teardown. Create the state directory explicitly (`mktemp -d`), pass it to the tool, and remove it with `trap 'rm -rf "$dir"' EXIT` in the same shell call that ends the tool.

**Why:** headless chromium, run through the probe and capture recipes in memory, created an implicit temporary profile per launch; every run killed by a timeout or a CDP teardown left it behind under `~/snap/chromium/common/chromium-headless/scoped_dir*`, up to ~146 MiB each (about 24 MiB on average). 1141 of them, 26.8 GiB, accumulated between 2026-08-18 and 2026-09-13, roughly 60 a day, and the user's daily cleanup script never looked there. Trials on 2026-09-13 showed only a killed run on the implicit profile leaks, and that a fixed shared profile is no fix either, since a concurrent session aborts on its lock (exit 21).

**How to apply:** for any recipe that launches a browser, a server, a notebook kernel or a build tool under a timeout, ask where it writes and whether a kill leaves it. The chromium form is in `rules/environment.md` (chromium row) and [[feedback_browser_layout_probe]]. When a cache or state directory grows at a daily rate with no obvious owner, check Claude's own recipes as a candidate source before blaming the user's tools. The `chromium-headless` module of `sys-cleanup` sweeps what still leaks (profiles whose `SingletonLock` names a dead pid).
