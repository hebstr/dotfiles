---
name: Deployment context for review calibration
description: Deployment context level used to calibrate code review severity in site-alisp (Quarto website published on Netlify)
metadata:
  type: project
---

`~/Documents/services/site-alisp` is `internal` for review severity calibration: flag bugs, correctness, security and maintainability, skip public-facing hardening and portability beyond the local stack.

**Why:** the automatic detection of `/audit:walkthrough` cannot classify it. The project carries no `.github/workflows/`, no `.gitlab-ci.yml` and no `Jenkinsfile`, the only three markers its CI classification tests, yet it carries a `netlify.toml` driving a CI build on every push to `main`, so the "under `$HOME` with no CI config" path heuristic does not apply either. Both steps fall through and the procedure asks. Answered by the user 2026-10-23: the site is public and deployed by CI, but it is a static editorial site with no backend, no auth and no user data, so full `production` adversarial severity is disproportionate while `personal` understates a public deploy.

**How to apply:** take `internal` without re-asking. The excluded categories (security, data integrity, correctness, privacy) stay fully evaluated whatever the level, and the one real input surface is `_resources/bureau.yml`, written by contributors through Sveltia CMS and read by `_lua/bureau-cards.lua`. See [[feedback_review_severity_personal]] and [[feedback_audit_walkthrough]].
