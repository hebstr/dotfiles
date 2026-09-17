---
name: Review severity for eds-avc pred/ orchestrator
description: "Calibrate code reviews of eds-avc's LLM inference orchestrator (pred/avc_pred_output.py, pred/lib/): documented GPU and env choices not to re-flag, and the R log parser fact reviewers get wrong"
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

Related: [[feedback_review_severity_personal]].
