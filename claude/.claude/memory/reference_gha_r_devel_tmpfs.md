---
name: reference_gha_r_devel_tmpfs
description: R-devel CI on ubuntu-latest: the 26.04 tmpfs /tmp, TMPDIR=$RUNNER_TEMP, and why P3M never serves a devel binary
metadata:
  type: reference
---

Three facts that together break an `R-CMD-check` `devel` job on GitHub-hosted runners, measured 2026-10-26 on `hebstr/edstr` (run `40336254101`).

**P3M serves no R-devel binary.** `packagemanager.posit.co/cran/__linux__/<codename>/latest` answers a request carrying an R 4.7 user agent with the source tarball and an R 4.6 one with a binary, on every distro: `HEAD` on `duckdb_2.0.0.tar.gz` returned 8.3 MB for R 4.7 on both `noble` and `resolute`, 23 MB for R 4.6. A `devel` job therefore compiles every dependency whenever its package cache misses, and the `actions/cache` key of `r-lib/actions/setup-r-dependencies` is prefixed by the OS string, so a runner-image migration invalidates it. Budget an hour for that first run; the ones after it hit the cache.

**`/tmp` on Ubuntu 26.04 is a RAM tmpfs**, half the RAM under a per-user quota, from systemd's `tmp.mount` (`actions/runner-images#14777`, open). The masking PR `#14814`, "Keep /tmp on the root disk", merged on 2026-10-20 and had not reached the deployed image on 2026-10-26, when the failure below was measured: the export is a workaround with an end, so check the issue before carrying it into a new workflow. `ubuntu-latest` migrated from 24.04 to 26.04 in late October 2026. R's tempdir sits there, which is where pak builds and unpacks, so a large source build dies on it. The symptom carries no reason at all: pak prints `Failed to install binary package <pkg>` seconds after a successful build, and nothing in the log says why.

**The fix is a first step exporting `TMPDIR`**, which is disk-backed:

```yaml
- name: Keep R temp files off the tmpfs /tmp of Ubuntu 26.04
  run: echo "TMPDIR=$RUNNER_TEMP" >> "$GITHUB_ENV"
```

A job-level `env: TMPDIR: ${{ runner.temp }}` does not work: the `runner` context reaches `jobs.<id>.steps.<id>.env` and not `jobs.<id>.env`, so the expression is rejected.

**Verified on `hebstr/edstr` run `40382373055`, 2026-10-26**: all three jobs green, `devel` in 87 min on `Cache not found` with duckdb 2.0.0 built from source (`[bld][cmp]`, 8.31 MB) and installed, `Status: OK`, against the 3.6 s install failure the same build hit before the fix. `release` took 54 min on a restored cache and `oldrel` 4 min. The step sits in the matrix job, so every job of the run carried `TMPDIR`: this run says nothing about whether a binary-only job needs it, and the cheap posture is to set it for the whole matrix rather than to reason about which job compiles.
