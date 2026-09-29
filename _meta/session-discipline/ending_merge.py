"""Merge the shard labels into the ending-gate bench and score the hook.

The sample is stratified: every stop point the hook fires on is in it, so its
precision is a census, while the silent stratum is a simple random draw and its
misses are extrapolated to the whole silent population with a Wilson interval
on the miss proportion. Pooling the two strata unweighted would understate the
misses, the draw covering 316 of 1,419 silent rows.

Shard 99 re-labels shard 00 through a second, independent labeller: their
agreement is the only measure of how much the single-reader limit costs, the
limit every earlier pass of this workstream recorded and none had sized.

Usage: python3 ending_merge.py   (reads ending_bench.json, ending_sample_index.json
and every ending_labels_*.json beside this file)
"""

import json
import math
import re
from collections import Counter
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
OVERLAP_SHARD = "99"
CLOSE_PHRASE = re.compile(r"/commit\b")


def wilson(k: int, n: int, z: float = 1.96) -> tuple[float, float]:
    """Return the Wilson score interval for k successes out of n."""
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    d = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / d
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (max(0.0, centre - half), min(1.0, centre + half))


def load_labels() -> tuple[dict[int, dict[str, Any]], dict[int, dict[str, Any]]]:
    """Return the primary labels by row id, and the overlap labels by row id."""
    primary: dict[int, dict[str, Any]] = {}
    overlap: dict[int, dict[str, Any]] = {}
    for path in sorted(HERE.glob("ending_labels_*.json")):
        shard = path.stem.rsplit("_", 1)[1]
        with path.open(encoding="utf-8") as fh:
            rows = json.load(fh)
        target = overlap if shard == OVERLAP_SHARD else primary
        for r in rows:
            target[int(r["id"])] = r
    return primary, overlap


def agreement(a: dict[int, dict[str, Any]], b: dict[int, dict[str, Any]]) -> dict[str, Any]:
    """Return raw agreement and Cohen's kappa on the rows both labellers saw."""
    shared = sorted(set(a) & set(b))
    if not shared:
        return {"rows": 0}
    la = [a[i]["label"] for i in shared]
    lb = [b[i]["label"] for i in shared]
    same = sum(1 for x, y in zip(la, lb, strict=True) if x == y)
    po = same / len(shared)
    ca, cb = Counter(la), Counter(lb)
    pe = sum(ca[k] * cb[k] for k in set(la) | set(lb)) / (len(shared) ** 2)
    kappa = (po - pe) / (1 - pe) if pe < 1 else 1.0
    disagreed = [
        {"id": i, "first": a[i]["label"], "second": b[i]["label"]}
        for i in shared
        if a[i]["label"] != b[i]["label"]
    ]
    return {
        "rows": len(shared),
        "raw": round(po, 3),
        "kappa": round(kappa, 3),
        "closure_raw": round(
            sum(1 for i in shared if bool(a[i]["closure"]) == bool(b[i]["closure"])) / len(shared),
            3,
        ),
        "disagreements": disagreed,
    }


def main() -> None:
    with (HERE / "ending_bench.json").open(encoding="utf-8") as fh:
        bench = json.load(fh)
    with (HERE / "ending_sample_index.json").open(encoding="utf-8") as fh:
        index = json.load(fh)
    primary, overlap = load_labels()

    rows = bench["rows"]
    labelled: list[dict[str, Any]] = []
    for i, r in enumerate(rows):
        if i not in primary:
            continue
        lab = primary[i]
        labelled.append(
            {
                "id": i,
                "session": r["session"],
                "timestamp": r["timestamp"],
                "stratum": "fires" if r["replay"]["families"] else "silent",
                "replay": r["replay"],
                "label": lab["label"],
                "closure": bool(lab["closure"]),
                "confidence": lab.get("confidence"),
                "quote": lab.get("quote"),
                "text": r["text"],
            }
        )

    fires = [r for r in labelled if r["stratum"] == "fires"]
    silent = [r for r in labelled if r["stratum"] == "silent"]
    offer_fires = [r for r in fires if "offer" in r["replay"]["families"]]

    tp = sum(1 for r in offer_fires if r["label"] == "offer")
    fp = len(offer_fires) - tp
    misses = sum(1 for r in silent if r["label"] == "offer")
    n_silent_total = index["strata"]["silent_total"]
    lo, hi = wilson(misses, len(silent))
    est_fn = misses * n_silent_total / len(silent) if silent else 0.0

    def recall(fn: float) -> float:
        return tp / (tp + fn) if tp + fn else 0.0

    per_phrase: dict[str, dict[str, int]] = {}
    for r in offer_fires:
        for p in r["replay"]["phrases"]:
            if CLOSE_PHRASE.search(p):
                continue
            slot = per_phrase.setdefault(p, {"true": 0, "false": 0})
            slot["true" if r["label"] == "offer" else "false"] += 1

    close_fires = [r for r in fires if "close" in r["replay"]["families"]]
    close_tp = sum(1 for r in close_fires if r["closure"])
    close_misses = sum(1 for r in silent if r["closure"])
    close_lo, close_hi = wilson(close_misses, len(silent))
    close_est_fn = close_misses * n_silent_total / len(silent) if silent else 0.0

    scoring = {
        "offer_half": {
            "fires_labelled_offer": tp,
            "fires_labelled_other": fp,
            "precision": round(tp / len(offer_fires), 3) if offer_fires else None,
            "silent_sampled": len(silent),
            "silent_labelled_offer": misses,
            "miss_rate": round(misses / len(silent), 4) if silent else None,
            "miss_rate_ci95": [round(lo, 4), round(hi, 4)],
            "estimated_misses": round(est_fn, 1),
            "recall_point": round(recall(est_fn), 3),
            "recall_ci95": [
                round(recall(hi * n_silent_total), 3),
                round(recall(lo * n_silent_total), 3),
            ],
            "per_phrase": dict(
                sorted(per_phrase.items(), key=lambda kv: -(kv[1]["true"] + kv[1]["false"]))
            ),
            "offer_labels_low_confidence": sum(
                1 for r in labelled if r["label"] == "offer" and r["confidence"] == "low"
            ),
        },
        "close_half": {
            "fires": len(close_fires),
            "fires_labelled_closure": close_tp,
            "precision": round(close_tp / len(close_fires), 3) if close_fires else None,
            "silent_labelled_closure": close_misses,
            "miss_rate_ci95": [round(close_lo, 4), round(close_hi, 4)],
            "estimated_misses": round(close_est_fn, 1),
            "recall_point": round(close_tp / (close_tp + close_est_fn), 3)
            if close_tp + close_est_fn
            else None,
        },
        "labels": dict(Counter(r["label"] for r in labelled)),
        "closure_true": sum(1 for r in labelled if r["closure"]),
        "low_confidence": sum(1 for r in labelled if r["confidence"] == "low"),
        "agreement": agreement({int(r["id"]): primary[int(r["id"])] for r in labelled}, overlap),
    }

    out = HERE / "ending_labelled.json"
    with out.open("w", encoding="utf-8") as fh:
        json.dump(
            {"meta": {**index, "scoring": scoring}, "rows": labelled},
            fh,
            ensure_ascii=False,
            indent=1,
        )

    print(f"{len(labelled)} labelled rows -> {out}")
    print(json.dumps(scoring, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
