# cpd000001 inference engine: which engine serves Qwen3.8-27B to opencode on three Turing cards?

2026-11-07.
Decision asked: does `cpd000001` keep the llama.cpp build it has, update it, or move to another engine (vLLM, SGLang, TensorRT-LLM, ExLlamaV3/TabbyAPI, ik_llama.cpp)?

**This note is about `cpd000001` only, and says `cpd000001` wherever it means the machine.**
A second CHU machine, `cpd000004`, carries a different configuration, so nothing measured or decided here transfers to it unchecked.
The bare `cpd` of this note's filenames and identifiers is not the machine: `_meta/cpd/`, `cpd-llama.sh` and the opencode provider `cpd` keep their names, which this precision deliberately leaves alone.

The verdict rests on the b9286 help dump already committed in `_meta/cpd/cpd-recon-20261104-151809.log`, on `docs/multi-gpu.md` fetched at both `b9286` and `master` and compared byte for byte, on the upstream issue and PR states read through `gh api`, and on two research passes whose every load-bearing claim was re-verified here before being written down.
It reopens "llama.cpp is updated to b11065 beside b9286, through `llama-update`" and the "Open points" entry of `.claude/DESIGN-CPD.md` on a throughput motive rather than an option-support one.

## Restating the question

Three questions whose answers diverge:

- Do the cards close the non-llama.cpp branch outright?
- Is the measured prefill a hardware ceiling or a configuration defect?
- Does the b9286 to current delta buy anything on sm_75 for prefill and for prompt-cache reuse?

Done means one answer per question, the two decisions kept separable (update the build, change the engine), an install footprint per candidate, a revisit trigger, and a revert path.

Out of scope: `cpd000004`, the other CHU `cpd` machine, which runs a different configuration and was not probed; the deferred thinking A/B, which `--reasoning-effort` still gates; any change to what `eds-avc` runs, which is an analysis decision; the multi-user service shape, deferred elsewhere.

## State at the opening

```
| Fact | Value |
|---|---|
| Machine | `cpd000001`, not the other CHU `cpd` machine `cpd000004`, whose configuration differs and is out of scope |
| Cards | 3 x Quadro RTX 6000, 24576 MiB each, sm_75 Turing, no NVLink recorded |
| Allocation | GPU 0 legacy Q4_K_M service on 8090; opencode run on GPUs 1 and 2 with `--split-mode tensor`; `eds-avc` a third consumer with `LLAMA_TENSOR_SPLIT=0,1,1` |
| Served | `unsloth/Qwen3.8-27B-GGUF:UD-Q6_K_M`, context 196608, `--parallel 1`, alias `qwen3.8-27b` |
| Binary | b9286, source commit 2026-05-22, compiled 2026-08-14, owned by `dvtle` under `/data2/llama_cpp_bin` |
| Reported baseline | about 50 tok/s prompt processing, about 32 tok/s generation, 17606 MiB per card, 2026-11-06 |
| Consumer | opencode 1.19.5, provider `cpd`, model id `cpd/qwen3.8-27b` |
```

Upstream was at b12189 on 2026-11-07, so the source gap is about 5.5 months.

## Protocol

Two research passes ran in parallel, one on official documentation and one on community practice.
Their reports are model output and were treated as unverified claims.
Every figure, flag, issue state and URL this note carries was re-checked here through `gh api`, `curl` or `WebFetch` before being written, and three of the community pass's framings were corrected in the process (recorded below).
The local half needed no network: the committed recon log holds b9286's full 640-line help, which settles which levers the running binary already has.

## Results

### The reported baseline is not a prefill measurement, and the whole motive rested on it

`_meta/notes/opencode-cpd-setup.md` records the figure as verified "with the script" on 2026-11-06, alongside "a chat completion answers in French" on a freshly started server on the test port.
No script in the repository measures prompt throughput: `recon.sh`, `trial-check.sh` and `trial-serve.sh` contain no `llama-bench`, no `prompt_per_second` and no timings read.
A short prompt on a cold server measures per-request overhead and any PTX JIT, not prefill throughput.

The comparison that carries weight is on the same silicon generation and the same model: 2 modded RTX 2080 Ti 22 GB (sm_75, same TU102 class, weaker cards), Qwen3.8-27B Q4_K, llama.cpp b10064, `-sm tensor`, `-fa on`, `-c 262144`, measured **776.805 tok/s prefill on a 21,201-token prompt**.
Secondary Turing points agree in magnitude: 2 x TU106 at 641 to 696 tok/s with `-ub 2048`, and 4 x Tesla T10 on PCIe 3.0 x8 at 978 tok/s with a 131072-token prompt.

So the reported 50 tok/s sits roughly an order of magnitude below every Turing datapoint retrieved.
It is not evidence of a hardware ceiling, and no engine comparison can be run against it.
Caveat kept: none of those points is at 196608 context, and prefill decays steeply with depth in every published table.

### The model is a hybrid Gated DeltaNet, which changes what caching can do

`Qwen3.8-27B` is `Qwen3_5ForConditionalGeneration`, 64 layers laid out as 16 blocks of three Gated DeltaNet plus one Gated Attention, so 48 linear-attention layers and 16 full-attention layers.
Attention is GQA 24/4 at `head_dim` 256, native context 262144.
Two consequences bind this decision: 196608 is inside the native window, so no YaRN is needed; and the model is a recurrent-state model, which is the case llama.cpp's prompt-cache machinery handles worst.

### TensorRT-LLM is closed mechanically

`ARCHITECTURES_WITH_KERNELS` lists 80, 86, 89, 90, 100, 103, 107, 120 and 121, and any other value raises a CMake `FATAL_ERROR`.
The live supported-hardware page lists Blackwell, Hopper, Ada and Ampere A100 only.
Turing was never in scope, so there is no deprecation to date: only Volta ever got an explicit removal notice.

### SGLang removed sm_75

`feat: remove sm75` (PR #9207) is merged, following the `[RFC] sm75 EOL` of 2026-05-04 (issue #6006, closed by the staleness bot with eight unanswered objections).
The shipped AOT kernel gencode starts at `compute_80`.
Issue #38515 measures the consequence on a 2080 Ti: a per-operation cubin gap where `silu_and_mul` and `gelu_and_mul` load while `rmsnorm` fails with `cudaErrorNoKernelImageForDevice` and no soft fallback.
The install page still advertises sm75, which is stale rather than a signal.

### vLLM runs on sm_75 and loses its prefill to Triton

The documented floor is `compute capability 7.5 or higher`, and the quantization matrix carries a Turing column marking AWQ, GPTQ, Marlin, INT8 W8A8 and GGUF as supported, with the single footnote that Turing does not support Marlin MXFP4.
Marlin is therefore not sm_80-gated, which corrects a common assumption.
FP8 W8A8 and W4A8 are both excluded, so the published FP8 and NVFP4 checkpoints of this model are out, and fp16 is the only KV dtype available at 196608.

The defeating fact is the attention backend.
FlashAttention requires sm_80 and FlashInfer is gated to sm_80, so Turing auto-selects `TRITON_ATTN`, and Triton has emitted no MMA below sm_80 since version 3.3.
Issue #60821 measures the result on a T4: zero `mma.sync` instructions in the compiled attention kernel, and 8k prefill at 9.479 s against 0.632 s with FlashInfer.
PR #55380, a one-line capability-floor change, has been open since 2026-09-04; one of its measurement sets runs this very model on 4 x Quadro RTX 5000 (sm_75, TP4) and reports a 17.7k-token cold prefill at 9.9 s with FlashInfer against 32.3 s on Triton.

Correction to the community pass: issue #57712 is on this exact card model (2 x Quadro RTX 6000, TP2, no NVLink) but its shared-memory failure is at `head_dim` 512, not at this model's 256, so it does not predict failure here.
The branch is open on paper and needs an unmerged patch to be competitive.

### ExLlamaV3 is the only engine with an upstream tensor-core prefill path for sm_75

PR #439 is merged (2026-10-08) and adds `exllamav3_ext/turing/fa75.cu`, a flash-attention forward on Turing HMMA `mma.sync.m16n8k8`, on by default on sm_75 and written for `head_dim` 256, which is exactly this model.
Its measurements run Qwen3.8-27B EXL3 4.0 bpw with a Q4 cache on a single RTX 2080 Ti 22 GB, prefill tok/s before and after: 2K 635 to 779, 8K 378 to 762, 16K 267 to 739, 32K 165 to 697, 64K 93 to 623.
Accuracy was checked over 32K of real cached prefill, perplexity 7.7167 to 7.7153.
The maintainer's statement of 2026-10-07 (issue #162) is that Turing is now supported, with performance "still not amazing".

The costs are real.
EXL3 is not GGUF, so the weights would be requantised or taken from a community branch, and the published runs are 4.0 bpw with a Q4 cache rather than Q6_K.
Upstream's published table stops at 64K; the 188K and 244K figures circulating come from the reporter's own unmerged fork (issue #417, open), whose four other mechanisms the maintainer declined pending minimal PRs.
Issue #568 answers the interconnect question directly: with PCIe and no P2P the all-reduce cannot be hidden, because each layer begins with the previous layer's output.
TabbyAPI, the OpenAI front-end, still restricts paged-attention batching to Ampere and higher in its README, while the Turing measurements above were taken through it, so that line needs a smoke test rather than trust.

### ik_llama.cpp has no evidence for this case

The README names "CUDA (Turing or newer)" as fully functional, while the repository title is a fork with better CPU performance and every prefill claim is CPU-side.
No prefill benchmark exists on any Turing GPU for a dense, fully-offloaded model, which is precisely the case asked about.
The maintainer has stated he has no Turing GPU to debug on, a verified Turing shared-memory fix was closed unmerged in August 2026, and a GTX 1660 Super report measures it at about half upstream's prompt processing with the maintainer's resolution being to use llama.cpp instead.
There is one release ever (`t0002`, 2025-07-22), the README states the last upstream sync was August 2024, and the row-interleaved gains that are its headline have no CUDA implementation for k-quants.
`UD-Q6_K_M` is not an `_XL` quant, so it should load, but no test of a UD Q6_K-class quant under this fork exists on any GPU.

### The split mode in use is the one tuned for generation, and the heuristic cuts both ways

`docs/multi-gpu.md` is byte-identical at `b9286` and `master` (10148 bytes, 127 lines), so this is not new guidance:

> `layer` (default) ... your priority is a fast prefill.
> Can tolerate slow interconnect speeds between GPUs.
> `tensor` ... your priority is fast token generation.
> Prefill speeds approach pipeline parallel speeds for large, dense models and fast GPU interconnect speeds.

PR #19378, which introduced the mode, carries the author's own benchmark on 2 x RTX 4090 with no NVLink possible, on `qwen35 27B`, this architecture:

```
| test | `-sm layer` | `-sm tensor` | ratio |
|---|---|---|---|
| pp512 | 3221.77 | 2927.23 | 0.91 |
| pp2048 | 4286.78 | 2712.77 | 0.63 |
| pp512 @ d65536 | 1843.62 | 2083.90 | 1.13 |
| pp2048 @ d65536 | 2486.88 | 2080.78 | 0.84 |
| tg128 @ d65536 | 41.25 | 53.48 | 1.30 |
```

Correction to the community pass, which read this as a clean win for `layer`: it is not uniform.
At the large ubatch a real prefill uses, `layer` wins at both depths; at small ubatch and depth, `tensor` wins.
The author's own rule is that tensor split "works comparatively better for slow GPUs with fast interconnect running large, dense models at large quantiztations and deep contexts".
This box is slow GPUs, a large dense model, a large quant and a deep context, all favouring tensor, with a slow interconnect, against.
The heuristic does not settle it, which is why the A/B is the action and not the assertion.

Independent PCIe-only points lean the same way as the table: 3 x Tesla V100 on Qwen3.8-27B Q4_K_M at pp4096 give `layer` 777.09, `tensor` 730.71 and a single GPU 774.81, so tensor scaled prefill negatively and layer scaled it to nothing.
The one positive Turing point, 2 x 2080 Ti reporting prompt processing from 500 to 650 tok/s, has NVLink.

Two further facts bind the split mode here.
`GGML_CUDA_ALLREDUCE` exists at b9286 with the Linux default `nccl` and alternatives `internal` and `none`; the 2080 Ti run above needed `internal` because NCCL crashed on its first real reduction over PCIe, later attributed to a distro package not matching the driver.
And a binary not compiled for native sm_75 silently drops to the pre-Turing dequant and cuBLAS path instead of MMQ, the `/data2` build's architecture flags being unknown because another user built it.

### Every prompt-cache lever already exists at b9286, and the one that sounds decisive is void here

From the committed help dump:

```
| Flag | Default | State in `cpd-llama.sh` |
|---|---|---|
| `--cache-prompt` | enabled | on |
| `-cram, --cache-ram` | 8192 MiB | default |
| `--cache-reuse` | 0, disabled | never set |
| `--cache-idle-slots` | enabled, requires unified KV and cache-ram | self-disabled |
| `--kv-unified` | enabled if slots are auto | off, because `--parallel 1` fixes the slot count |
| `--slot-save-path` | disabled | unset |
| `-ctk` / `-ctv` | f16 | unset, and refused under tensor split at this build |
```

b9286 logs `--cache-idle-slots requires --kv-unified, disabling`, which is the mechanism behind that row.
`--reasoning-effort` is the one genuine absence, confirmed against the help dump rather than against the probe, whose six false negatives this repository already records.

`--cache-reuse` is withdrawn as a lever: it does not work with recurrent-state models, which this model is, and the clearest community statement of its semantics is that it is misleadingly named, being a trick to keep the tail of a prefilled sequence after deleting earlier parts while pretending they are still there.
Discussion #22354, on opencode specifically, reports `--cache-reuse 256`, `--cache-reuse 2048` and `--swa-full` all failing to prevent a full reprocess of about 100k context on an agent switch.

### Prompt-cache reuse for this model is limited upstream, not by the build

Issue #24055, "Context checkpoints always invalidated on hybrid/recurrent models", has been open since 2026-06-03, with three fix PRs still open.
Issue #30357, open, measures a Qwen3.5-plus specific defect: the server's reasoning and content whitespace is not round-trippable through the chat template, so a correct client still mismatches the cached prefix.
On two Qwen3.8-27B quants at 128K with q8_0 KV, a prompt 25 tokens longer than the cached one reprocessed 7,260 tokens in 41 s.
The maintainer's workaround is to strip leading and trailing whitespace from the response client-side.

The harness contributes its own invalidation.
opencode's system prompt carries the date, so crossing midnight invalidates everything; `AGENTS.md` is reloaded into the prompt when edited mid-session; and the `<available_skills>` block is reported to have taken one user's cache miss rate from 1 to 2 percent up to 10 to 15 percent.
Tool-set changes force a full reprocess by construction, and the upstream position is that a prefix which changes cannot be cached.
Issue #29947 is literally this model plus opencode, and its resolution is that the unsloth template works where the ggml-org one raises, so this setup is already on the good side of it.

Two traps to avoid: `--cache-ram -1` is documented as "no limit" but the token cap stays at `n_ctx` and RAM grows about 640 MiB per short prompt on hybrid models (issue #29324, open, on a command line close to this one), and pinning `id_slot` to an empty slot skips the prompt cache entirely.

### What the update would buy on sm_75

```
| Change | Build | Effect here |
|---|---|---|
| PR #23792, quantized KV under tensor split | b9455 | the b9286 refusal string is gone at `master`, so `-ctk q8_0 -ctv q8_0` becomes legal under `-sm tensor` |
| PR #25749, CUDA graphs on Volta and Turing | b10042 | previously off on sm_75, author reports major gains with `-sm tensor` |
| PR #24491, Turing P2P access fix | b9875 | fixes an out-of-bounds all-reduce write crashing `-sm tensor` on Turing |
| PR #29948, FFN gate/up and GLU fused in MMQ | b11879 | scoped Turing and newer, measured on Qwen3.8-27B Q6_K at 751.2 to 785.8 tok/s |
| PR #28079, missing FA kernel warning | b10876 | the matched-pair KV fallback was silent at b9286 |
| checkpoint and cache work | various | checkpoints at every user message, strict `--cache-ram`, reference-counted checkpoints, all after b9286 |
| `--reasoning-effort` | b11065 and later | unblocks the deferred thinking A/B |
```

The documentation contradicts the first row: `docs/multi-gpu.md` still states that KV types must be non-quantized under `tensor`, and has not been touched since 2026-05-07.
Flag removals that would break a launcher do not touch this one: the `--mmap` and `--mlock` family folded into `-lm, --load-mode` (PR #28334) and `-cpent` became `-cms`, and `cpd-llama.sh` uses none of them.
`--fit` survives at `master`, where it is documented as unsupported with `tensor` in any case.

### KV quantisation buys VRAM, not prefill, and only in matched pairs

Only `q4_0-q4_0`, `q8_0-q8_0`, `f16-f16` and `bf16-bf16` are compiled as flash-attention quant pairs.
A mixed pair falls back to f16 conversion described as slow in the source warning; issue #27109, closed, measures 4-bit K with 8-bit V on this architecture collapsing prefill to about 34 tok/s against 991 to 1276 for `q8_0/q8_0`, and issue #31213 is three reporters hitting the same wall, two of them on this model above 340k context.
On Turing specifically, prefill is flat within about 1 percent across f16, q8_0 and q4_0, with f16 marginally ahead, so quantised KV is a VRAM lever rather than a speed lever.
Where it does cost is decode at depth, around 55 percent of f16 throughput at 64K for q8_0.
No KV quality measurement above 32K context exists from anyone, so the 196608 question is unevidenced on quality.

### `awesome-local-ai` does not carry the weight the design note gave it

The repository is 62 stars, `subscribers_count` 1, zero issues and zero pull requests ever, discussions disabled, one contributor, and 99 of its last 100 commits carry an AI trailer.
Its own footnotes mark both SGLang rows as unmeasured by the repository.
The path `.claude/DESIGN-CPD.md` cites, `combinations/qwen/3.8/27b/ubuntu/24GB/llamacpp-opencode/config.sh`, no longer exists: the `24GB` tier was replaced by `nvidia3090/sglang-opencode` and `nvidia4090/llamacpp-pi`.
That citation stays in the design note as a record of what was read on 2026-09-24, which was accurate then.

The surviving llama.cpp row still floors the build at `MIN_LLAMA_COMMIT_DATE="2026-08-13"`, now justified as needing qwen3_5 hybrid plus draft-mtp rather than the chat template, and it measures its `coding` profile at 128k with q4_0 KV on one 24 GB card at 2309 tok/s prefill, with MTP speculative decoding taking generation from about 44 to about 92 tok/s.
Its README disclaims this case outright, being a single-GPU single-user setup that points multi-GPU users at vLLM or SGLang.
The new SGLang row for 24 GB cards is triply closed on sm_75: kernels AOT-built for sm_86 with no PTX, a declared minimum capability of 80, and an fp8 KV cache.
So the floor is one author's measurements on one 4090 with no independent replication, and the 2026-11-04 trial already showed b9286 runs this model.
It is a useful configuration reference and not a reason to update.

## Decision

**The engine does not change: `cpd000001` keeps llama.cpp.**
TensorRT-LLM and SGLang are closed on the hardware.
vLLM and ExLlamaV3 are technically alive on sm_75 and both would be real projects, but neither can be priced against a baseline that is not a prefill measurement, and ExLlamaV3 additionally requires leaving GGUF.

**The build does not change yet: `cpd000001` keeps b9286 for now, and the update is held as a separate second step.**
This upholds the decision of 2026-11-04 on a new motive rather than reversing it, because the deciding measurement has not been taken.

The ordered actions, all inside the existing binary and the user's own `cpd-llama.sh`, none needing root:

1. Re-measure prefill warm, at a realistic depth, with a long prompt, and record the command and the depth alongside the number.
2. Read the startup log for the NCCL unavailability warning and for the compiled architecture.
3. A/B `GGML_CUDA_ALLREDUCE=internal` against the default.
4. A/B `-sm layer` against `-sm tensor` at a realistic `-ub` and depth.
5. Add `--kv-unified` so `--cache-idle-slots` stops disabling itself, and never set `--cache-ram -1`.
6. On the opencode side, disable the `title` and `summary` sub-requests and pin reasoning effort to `low` or `medium`, the template accepting only `xhigh`, `medium` and `low`.

If those recover prefill into the several-hundred tok/s range the Turing evidence predicts, both the update and the engine change lose their motive.
If they do not, the update becomes motivated on its own evidence, led by quantized KV under tensor split and CUDA graphs on Turing.

### Install footprint and the `/opt/llama` question

The decision keeps the footprint at zero: no install, no new path, no root, and `/opt/llama` stays uncreated, as settled on 2026-11-04.

Had an engine changed, root would still not have been required.
vLLM installs into a user-home `uv` venv with pre-compiled binaries and no system CUDA, and ExLlamaV3 with TabbyAPI likewise, TabbyAPI's own start script creating the venv.
TensorRT-LLM is the only candidate that needs system packages and a container, and it is closed on other grounds.
So an engine change would reopen the question of who owns the running service, not the question of root.

### Revisit trigger

Any of: the re-measurement of step 1 landing well below the Turing datapoints after steps 2 to 4; `dvtle` rebuilding or deleting the `/data2` binary, whose escape hatch remains the b11065 route of the superseded design section; vLLM PR #55380 merging, which would restore FlashInfer on sm_75 and make that branch worth pricing; upstream closing issue #24055, which is the ceiling on prompt-cache reuse for this model.

### Revert path

Steps 3 to 6 are an environment variable and launcher flags, so reverting is editing `cpd/cpd-llama.sh` back and restarting.
Nothing is installed, so there is nothing to uninstall.

### Usage warning

`-sm tensor` is marked experimental in the server help, which is worth registering given it runs in production on a shared machine.
A larger `-b` raises prefill and also raises every co-tenant's worst-case stall, one prefill chunk blocking decode for all sequences (issue #29175, open), so batch sizing on this host is not a free lever.
Do not lift the Turing flash-attention Q-tile cap discussed in issue #28761: the register spill it introduces is at `head_dim` 256, which is this model.

## What stays uncovered

- No prefill benchmark exists on a Quadro RTX 6000 for a 27B model, on three cards, or at 196608 depth on Turing.
  Every number here transfers from a different card count or depth.
- Whether Q4_K_M beats Q6_K on prefill on sm_75 is unanswered by anyone; prefill goes through MMQ at every batch size on Turing, so it is kernel-dependent and not monotone in bit width.
- Whether the `/data2` build carries native sm_75 SASS or PTX only, which step 2 answers and which bounds every figure measured on it.
- Whether TabbyAPI's paged batching works on Turing, its README and the ExLlamaV3 measurements disagreeing.
- Prompt-cache quality and behaviour above 32K context, unmeasured by anyone on any GPU.

## Sources

Verified here on 2026-11-07 through `gh api`, `curl` or `WebFetch`.

- llama.cpp merged: PR 19378 tensor parallelism and its benchmark table, PR 23792 quantized KV under tensor split, PR 24491 Turing P2P fix, PR 25749 CUDA graphs on Volta and Turing, PR 29948 MMQ FFN fusion, PR 28079 FA quant compile control, PR 28334 load-mode flag removal.
- llama.cpp open: issue 24055 hybrid checkpoint invalidation, issue 30357 whitespace round-trip, issue 29324 `--cache-ram -1`, issue 29175 co-tenant prefill stalls, issue 28761 Turing Q-tile cap, issue 31213 KV quant pairs, issue 29947 this model with opencode.
- llama.cpp closed: issue 27109 mixed KV prefill collapse, issue 22746 full reprocess on tool change.
- `ggml-org/llama.cpp` `docs/multi-gpu.md`, identical at `b9286` and `master`; `GGML_CUDA_ALLREDUCE` present in `ggml/src/ggml-cuda/ggml-cuda.cu` at both refs.
- vLLM: `docs/getting_started/installation/gpu.cuda.inc.md` and `docs/features/quantization/README.md` at `main`; issue 60821, PR 55380, issue 57712.
- SGLang: PR 9207 merged, issue 6006, issue 38515.
- ExLlamaV3: PR 439 merged, issue 162, issue 417, issue 568.
- `boxabirds/awesome-local-ai`: the two surviving combination directories under `combinations/qwen/3.8/27b/ubuntu/`.
- <https://ai-muninn.com/en/blog/qwen38-dual-2080ti-tensor-parallel> for the 2 x 2080 Ti figures, one author, one to two runs per configuration.
