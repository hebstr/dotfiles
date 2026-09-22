---
name: Review calibration for the edscrib Python package
description: "Calibrate reviews of the edscrib annotation socle (~/Documents/packages/py-edscrib): never soften severity, the reviewer's mechanism is reliable and its tier and remedy are not, standing rejections not to re-raise, and the framework and library facts twelve passes established"
metadata:
  type: feedback
---

Calibration drawn from twelve `/audit:walkthrough` and `/audit:blindspot` passes on `py-edscrib`, 2026-07-29 to 2026-08-02 (`navigation.py` twice, `auth.py` twice, `app.py` five times, `export.py` twice, `config.py`; reviewer `posit-dev:critical-code-reviewer` unless noted).
Project context in [[project_edscrib_annotation_package]].
Every L2 consensus count these passes recorded went through the Ouroboros `claude_code` backend, so it is intra-family agreement, not cross-provider confirmation (see [[feedback_ouroboros_tools]]); the counts are left out below for that reason.

## Severity: never soften, and read the mechanism rather than the tier

`edscrib` is neither a personal script nor a CRAN-style package: it is a shared socle heading for a Git-tagged dependency of several clinical annotation projects, and the parquet its write path touches is an irreversible gold standard. [[feedback_review_severity_personal]] does **not** apply here, even when its generic description matches.

- **The reviewer reads the mechanism well and calibrates the tier poorly, in both directions.** Across twelve passes, tiers moved up (Suggestion to Blocking, Suggestion to Important) as often as down; one pass moved three of four down. Do not learn "it under-rates" or "it over-rates": reproduce, then set the tier.
- **The reviewer's remedy is where it fails.** Its mechanism held on all eleven findings of the render pass while its remedy was wrong on four; the same shape recurred in every pass. Re-derive the remedy from what the code guarantees, never from consistency or from the one offered.
- **Cross-model L1 is worth its cost here, and its mechanism claims are checkable.** It reversed or corrected Claude's work in most passes, including two of Claude's own remedies in one session and a rejection Claude had built on a strawman measurement. It was also right in conclusion and wrong in mechanism in the same answer: take its verdict seriously and verify its mechanism.
- **Justify an escalation on the axis that carries it.** When nothing is written wrong and nothing is lost, the axis is misdiagnosis or unavailability, not the clinical stakes; an escalation argued on the stakes alone is unfalsifiable.
- **Adjudicate claim by claim.** A multi-claim finding is accepted or refused per sub-claim; a refused remedy still leaves its diagnosis to adjudicate; both of a finding's examples can be wrong while its mechanism holds; a Suggestion's remedy deserves the scrutiny of a Blocking's.
- **Self-inflicted defects are the worst findings on this repo.** Twice in one `auth.py` session the most serious outcome was a regression Claude introduced minutes earlier, and Claude's repair of it was itself incomplete. A fresh adversarial round after a multi-fix walkthrough stays mandatory here.

## What to keep flagging

- Unguarded `.loc` assignment (pandas setting-with-enlargement appends a phantom row or column and persists it), a non-atomic `to_parquet` over the single copy, a frontend-only `disabled` guard with no server-side re-check, and tests green without being discriminating.
- **Consequences of the two instructed blind spots' interaction.** Addressing the row by index label, and writing with `index=False` where output creation writes the index, are both specified and pinned: do not report either as a discovery. But the first save rewrites the index to a `RangeIndex` while the cursor stays on its seed label, so a second save on a non-0-based frame appended a phantom row.
- **A guard separated from its write by a rerun boundary proves nothing about the write.** Streamlit fires `on_click` before the rerun, so a guard in `load_frames` sees the output earlier than the click; a document inserted ahead of the cursor passed every load-time guard and the annotation for `B` landed on `A`. Identity is re-verified under the lock.
- **A write that normalizes launders the evidence a guard waits for.** A duplicated label away from the addressed row passes, the write succeeds, and since the index is not persisted the labels come back contiguous. Ask of every silent repair what signal it destroys.
- **A callback reads what the framework refreshed, never what the body wrote.** A value mirrored under a second `session_state` name is one completed render behind at save time: a correction from `oui` to `non` reached the gold standard as `oui`.
- **Removing two overlapping mechanisms in one change leaves a hole neither test covers.** Enumerate what only their intersection covered (here: an input regenerated with the same ids and columns but corrected values, closed by `frozen_fields`).
- **A guard that instructs a repair is worthless until the repair can be observed.** An unkeyed cache in front of the guard made "Rebuild the data" loop forever; check the cache in front of every guard that asks for one.
- **Widening a validation widens every call site that validation sits on.** Streamlit reruns everything, so "called once at startup" is almost never true: a render-time deployment guard belongs behind the authenticated early return.
- **Narrowing a catch widens what escapes.** Before narrowing, enumerate what the broad form held by accident; verify escape classes by enumeration (directory, unreadable, absent, malformed, wrong encoding, NUL in the path), not by the case that prompted the fix. `tomllib` decodes bytes first, so a latin-1 file raises `UnicodeDecodeError`, a `ValueError` that is no `TOMLDecodeError`.
- **An exception message is an egress the module owns.** Shrink what can escape (a precondition that refuses by column and position) rather than what is caught.
- **A guard reading a derivation is blind to what the derivation drops.** Two guards reading `persisted_fields` missed the collision spanning a persisted and a non-persisted group; they read `rendered`. Widening a guard's input set widens what it stops the app for, which is a decision to surface, not a side effect.
- **A demotion covering one branch of a binding covers neither.** `Cell._bind_value` types a leading `=` as a formula and a string equal to an `ERROR_CODES` entry as an error; demoting only the first lost `#N/A` and `#REF!`.
- **Labels a consumer supplies are not unique on either axis.** Iterate `data.items()`, not `data[name]`, and dedupe derived name lists (`dict.fromkeys`).
- **Two identity guards can be defeated by a keyword**: transposed positional `str` fields made `aligned` compare a counter against itself. `kw_only=True` is on `AnnotConfig` (and on `Tuto` and `Styles`), not on `FieldGroup` or `NoteField`; on `NoteField` it breaks 33 of 53 tests and the declared-column guard already stops the one transposition. Decide such a flag per class by running the suite.
- **A docstring's "safe because callers do X" is not a mechanism.** `st.stop()` is annotated `NoReturn` but returns when no script run context exists, so every guard fell through to the write off the script thread. The remedy is `_halt` raising `_Stopped(BaseException)`, and the module's own `except Exception` needed the same fix.
- **A redundancy is the defect.** Two declarations of one decision (a widget's editability and its group's persistence) produced a default that renders a live widget nothing saves; the field was removed, the group's `persisted` alone decides.

## Standing rejections: do not re-raise

- **Extracting the composition out of the display shell** (`save()` closure to a module-level `_commit`). The "logic in plain functions" rule is scoped to `st.dialog` and `st.fragment`, which `AppTest` cannot execute (streamlit#9786, #9242); an undecorated shell is reached by `AppTest.from_function`.
- **Normalizing the index inside `build_output` or `read_data`** (`reset_index(drop=True)`). `save_notes` re-reads the parquet raw under its lock, so a memory-only reset splits memory from disk; the remedy kept is the `labelled_by_position` guard.
- **Restructuring `rows` for an unwritten render consumer**, and a `__post_init__` validation that would cement `table_fields ⊆ df_output.columns`: both guess at a layout decision no one has made. Before validating a constraint, ask whether it is a decision or a fact.
- **Bounding the `FileLock`, or aligning `save_notes` on `is_singleton=True`.** `filelock` resolves to `UnixFileLock` over `fcntl.flock`, released by the kernel on process death, and a bounded timeout would skip the write and the cursor advance. The non-singleton's `RuntimeError: Deadlock` on re-entry is the safe refusal; the singleton would write a note under a frame the outer hold is about to write back. Re-examine rather than dismiss on a network mount, where `flock` is kernel-local.
- **Performance findings refused on measurement**, with the numbers written into the docstring: the input `st.cache_data` (0.9 to 2.27x a raw read), the double output read (2.9 to 9.5 ms over 500 to 50 000 documents), the `build_workbook` vectorization (the targeted loops are 2.4 % of 2.19 s). Separate the free lock narrowing from the trade that buys milliseconds with coupling.
- **A remedy's stated basis that measures false.** The `else`-clause proposal rested on pyrefly accepting the return only through `NoReturn`; four regimes showed the same regression caught and the same one missed either way.

## Method that settled points on this target

- **Reproduce or measure before rejecting**, and sweep the dependency's declared floor as well as the locked version when a rejection rests on library behaviour (`filelock` 3.29.0 to 3.32.0).
- **Check that the reported scenario is the one the code constructs.** The reviewer's 2.0 s lock hang was two threads, where the code has one; Claude's own strawman measured a caching scenario nobody proposed.
- **Read the consumer, not a reconstruction of it**: its `can_save` before claiming a live loss, its widget keys before a claim about carry-over, its parquet schema before a claim about what an input can carry, its stylesheet before pricing a render finding.
- **Decode the vendored Streamlit bundle** (`.venv/.../streamlit/static/`) before accepting a framework claim; attribute names survive minification.
- **Fetch a citation before taking a severity from it**, including from L1. Office's column width limit is MS-OI29500 18.3.1.13, an implementation requirement, not an ECMA-376 XSD facet.
- **Look for the second site of a question in the repo** before arguing it from principle (the `unresolved` guard settled log-plus-message; `load_frames` is where shape checks live, almost never the dataclass).
- **Mutate each guard separately**, narrow `pytest.raises` with `match=`, mutate a guard ordering rather than trusting the prose, and after closing a fall-through read which tests change behaviour, not only which fail. A test asserting against a module constant tests nothing: assert the rendered surface and the log.
- **Test a stop-under-contention on its own thread against a timeout**, never in line, or a regression hangs the suite.
- **Some guarantees the gate cannot hold** (a rebuilt-dictionary type, `persist_state=None`): say they are held by review and `pyrefly`, not by the suite.
- **Prefer a generic walk to an enumeration** on a shape still growing (the `{user}` placeholder guard became a recursive walk over `dataclasses.fields`, testing `str` before `Iterable`).
- **A cross-repo signature change is cheapest taken whole**, both `eds-avc` apps migrated in the same pass; a public-contract change lands cheapest before the `v0.1.0` tag.

## Facts established

- `StopException` and `RerunException` derive from `ScriptControlException(BaseException)`, so a broad `except Exception` at a display boundary does not swallow `st.stop()`; the broad form is this codebase's settled choice.
- Two distinct `FileLock` objects over one path deadlock inside one process; `is_singleton=True` makes them one reentrant object and changes only intra-process bookkeeping.
- `pyrefly` accepts `return users` under `-> dict[str, str]` after an `isinstance` loop over parsed TOML: type narrowing is earned by rebuilding the dict, not asserted.
- Two int64 ids past 2⁵³ compare equal as float64, so dtype parity between readers is correctness: `save_notes` reads through `edscrib.io.read_data`.
- `Series.equals` compares dtype and values at once, so a dtype drift between library versions reads as a changed value; the log carries both dtypes.
- `(st_mtime_ns, st_size)` is not a file identity; `st_ino` closes stage-and-rename, an in-place rewrite still rests on mtime.
- `warnings.catch_warnings` swaps the process-global filter list and is unusable in a multi-session server.
- openpyxl: a title colliding case-insensitively with the default is renamed; a leading `=` binds as a formula and French shorthand (`=>`, `= idem`, `=/=`) is lost unless demoted to `s`; `MergedCell.data_type` is a read-only class attribute. `pd.ArrowDtype(pa.string()).kind` is `U`, so a string filter needs `kind in {"O", "U"}`.
- Streamlit 1.60: `help=` sets `aria-describedby` beside the accessible name, not a `title`; `on_click="ignore"` sets `ignore_rerun` on the proto, testable there; `st.radio(options=[])` renders and holds `None`; a disabled slider leaves the tab order; `menu_items={}` is a no-op; `st.iframe` with a raw string is `srcdoc`, the sandbox is `allow-same-origin allow-scripts` together, and a `data:` URL gives an opaque origin at the cost of content sizing. Sanitising corpus markup is refused: it repairs a clinical record in silence.
- RFC 8265 (PRECIS `OpaqueString`) mandates NFC for passwords and forbids case mapping; usernames fall under the same RFC and remain unnormalized, deferred.
- The export gate reads the same `[users]` table as the login, so it is authentication a second time, never authorisation.

## Form the next descents copy

Hardcoded `st.session_state` keys are allowed but declared in the docstring and checked at render. Guards raise rather than repair, and any guard that logs a detail says so on the page. The `AppTest.from_function` harness exposes every public parameter. Availability beats diagnosability on the login gate: a half-typed entry is a warning, not an outage for every other annotator. A behavioural guarantee needs a test that fails when it is removed, proven by mutation.
