---
name: Env var substitution inside a plugin skill
description: Two measured facts about the variables a plugin skill can rely on: `${CLAUDE_PLUGIN_ROOT}/path` may render a double slash, which is never "fixed" in the source, and `${CLAUDE_SKILL_DIR}` is guaranteed in hooks but empty in a skill's own Bash calls
metadata:
  type: reference
---

Both observed 2026-04-25 on the `hebstr` marketplace, which was then added by local path; not re-verified since.

**`${CLAUDE_PLUGIN_ROOT}/path` can render `<root>//path`.** Seen as `claude-code-plugins//audit/...` in `audit/blindspot/SKILL.md`. The canonical form stays `${CLAUDE_PLUGIN_ROOT}/path`: no trailing slash on the variable, a leading slash on the path, as `r-skills` writes it. The doubled slash is a runtime substitution bug, never an error in the source, and its practical effect is nil since POSIX treats `//` as `/`. Dropping the leading slash to make the rendered path look clean breaks every call site the moment the substitution is patched upstream.

**`${CLAUDE_SKILL_DIR}` is not exported to a skill's Bash calls.** It is guaranteed in hooks (`r-skills/hooks/hooks.json` relies on it), but a live `echo $CLAUDE_SKILL_DIR` from a skill's Bash tool call returns empty. Keep writing `${CLAUDE_SKILL_DIR}` anyway, resolved against the `Base directory for this skill: <path>` header the harness injects at the top of the skill prompt. A hardcoded path is the wrong fallback: the cache directory is versioned by sha, so it goes stale at every plugin update.

**How to apply:** leave both forms alone, in the source and in a review. A `//` in a rendered path is not a finding, and neither is `${CLAUDE_SKILL_DIR}` used without a shell default. The distinct and real failure is `$CLAUDE_PLUGIN_ROOT` left *unset* in dev mode or a non-plugin install, which `audit/blindspot/SKILL.md` handles by its documented resolution fallback, as `audit/walkthrough/agents/orchestrator.md` and `agents/cross-model-bridge.md` do for `${CLAUDE_SKILL_DIR}`. See [[reference_claude_code_marketplace_mechanics]].
