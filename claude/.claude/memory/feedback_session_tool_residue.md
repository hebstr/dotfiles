---
name: Tools Claude launches leave residue when a timeout kills them
description: A process Claude starts from the Bash tool and that gets killed (timeout, torn-down CDP session) skips its own cleanup; give every such tool a throwaway state dir removed by an EXIT trap in the same call, and suspect Claude's own recipes when a residue grows fast
metadata:
  type: feedback
---

When a tool launched from the Bash tool creates temporary state and may end by being killed rather than exiting, that state is never cleaned: the kill skips the tool's own teardown. Create the state directory explicitly (`mktemp -d`), pass it to the tool, and remove it with `trap 'rm -rf "$dir"' EXIT` in the same shell call that ends the tool.

**Why:** Claude's own headless chromium recipes leaked one implicit profile per killed run, measured in the chromium row of `rules/environment.md`, and the user's daily cleanup script never looked there.

**How to apply:** for any recipe that launches a browser, a server, a notebook kernel or a build tool under a timeout, ask where it writes and whether a kill leaves it. The chromium form is in `rules/environment.md` (chromium row) and [[feedback_browser_layout_probe]]. When a cache or state directory grows at a daily rate with no obvious owner, check Claude's own recipes as a candidate source before blaming the user's tools. The `chromium-headless` module of `sys-cleanup` sweeps what still leaks (profiles whose `SingletonLock` names a dead pid).
