---
name: Review severity for eds-avc pred/ orchestrator
description: "Calibrate code reviews of eds-avc's LLM inference orchestrator (pred/avc_pred_output.py, pred/lib/) and of its R log parser (config/helpers_pred_logs.R): documented GPU and env choices not to re-flag, the run/log correspondence reviewers get wrong, and the five false-positive shapes of the 2026-09-17 parser pass"
metadata:
  type: feedback
---

Calibration for reviews of `pred/` in eds-avc (llama-server orchestrator, one fixed 3-GPU CHU server), from the 2026-09-17 walkthrough of `pred/lib/server.py` and `pred/avc_pred_output.py` (13 findings: 7 accepted, 4 rejected, 2 noted).

**Why:** four findings were rejected as documented design, hypothetical portability, or negligible cost, and one accepted finding carried a remedy that would have broken the R consumers.

**How to apply:**
- Do not flag the hardcoded `CUDA_VISIBLE_DEVICES="0,1,2"` in `start_server`: it is documented in `.claude/llama_tuto.md` as the multi-GPU proxy for the single 3-GPU target, and every split in use has three entries.
- Do not ask to move the server-only env reads (`LLAMA_FLASH_ATTN`, `LLAMA_BATCH_SIZE`, `LLAMA_UBATCH_SIZE`, `LLAMA_TENSOR_SPLIT`) into `config.py`: `config.py` holds what the clients share, `server.py` what only the llama-server command line consumes.
- Do not flag per-prompt re-reads of the input parquet: one prompt is active, so the cost is nil against inference.
- Before accepting a remedy that touches log or output file names, check the R consumers: `config/helpers_pred_logs.R` treats one `.log` file as exactly one run (`run_id` = basename, header on first match, tasks joined by `task_id` over the whole file) and rebuilds `run_id` from the parquet name, and `pred_output_ls()` globs `*output*.parquet`. Appending to a log, timestamping its name, or suffixing a sampled output all break or pollute them.
- The `/v1/models` id under `--hf-repo` is the raw repo string, so its kebab equals the CLI-derived kebab; check the file names in `pred/data/` and `pred/logs/` before accepting a naming-mismatch claim.

## `config/helpers_pred_logs.R`, walkthrough of 2026-09-18, commit `1bf98a5` (13 findings: 5 accepted, 5 rejected, 3 noted)

**Why:** every rejection turned on the same axis, a remedy that would have replaced a loud failure with a silent one, or a claim resting on a unit of work the pipeline does not have.

**How to apply:**
- **A run is a model, not a model x prompt pair.** In `avc_pred_output.py`, `for prompt_name in prompts` sits inside the per-model `with log_path.open("w")` and a single `start_server`, so one `.log` covers every prompt of that model and `run_id` carries no prompt segment by design. Reject any remedy keying `docs` on `run_id` + `prompt_id`: it would fragment the docs list finer than `runs` and `tasks`, which stay split by `run_id`. `prompt_id` is a column, and that is where the per-prompt split belongs.
- **Do not trade a loud abort for a fabricated value.** Three rejected remedies did exactly that: deduplicating Excel sheet names (openxlsx2 raises `Cannot shorten sheet name to a unique string` on a real collision, and 0 of the 10 current names collide at 31 characters), collapsing a length->1 list in `.meta_chr` with `paste(collapse = " ")` (the documented case is the length-0 element, and `pred_quote` is a `json.dumps` scalar pinned `pl.Utf8` in `sink.py`), and adding `pred_avc`/`pred_quote`/`pred_think` to `meta_defaults` (present on 27/27 columns checked, written in both the success and the failure record of `inference.py`; the current abort is what catches a file wrongly caught by the `*_output_*.parquet` glob).
- **`.col` is a session constant** built in `.Rprofile` from `_variables.yml` and read in nine files; `proj`/`split` are arguments because they vary per call and the tests parametrize them. Do not propose turning `.col$id` into an argument of this one helper.
- **Two guards to preserve, added in this pass**, so a later review does not read them as redundant: the `relationship = "one-to-one"` on the release join (a duplicated `task_id` would inflate `n_req`/`n_completed`/`n_truncated` by silent fan-out), and the `n_req == 0` + docs-present warning in `logs_check_orphan_runs()`. The reverse case, `n_req > 0` with no docs, is deliberately silent: the parquet is written once after the inference loop, so an interrupted or in-progress run legitimately has none. A strict `n_req == nrow(docs)` equality is equally wrong, since a resumed run relaunches only the remaining tasks into a freshly rotated log.
- **`status` reclassifies only what would read `complete`.** The `interrupted` branch sits after the `test` branch on purpose: the `test-model` fixture carries an unreleased task and asserts `"test"`.

Related: [[feedback_review_severity_personal]], [[feedback_review_severity_heuristic_code]].
