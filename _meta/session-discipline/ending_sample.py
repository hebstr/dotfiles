"""Draw the labelling sample from the frozen ending-gate bench and shard it.

Ground truth for the "offer without a position" half of ending-gate.sh cannot be
derived lexically: a labeller has to read the message. This draws every stop
point the hook fires on, where precision is measurable exactly, plus a simple
random sample of the silent ones, where recall is estimated. Enriching that
draw lexically would make the measure circular, which is the objection the
reco-relance.sh measure had to answer.

Each shard carries the message text and nothing else: no verdict, no phrase, no
mention of the hook, so a labeller reading one cannot align with the pattern
under test.

Usage: python3 ending_sample.py [bench.json]   (default: ending_bench.json here)
"""

import json
import random
import sys
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
SEED = 20260929
SILENT_DRAW = 316
SHARD = 50
OVERLAP = 50


def shard_path(n: int) -> Path:
    return HERE / f"ending_shard_{n:02d}.json"


def main() -> None:
    bench = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "ending_bench.json"
    with bench.open(encoding="utf-8") as fh:
        rows: list[dict[str, Any]] = json.load(fh)["rows"]

    fires = [(i, r) for i, r in enumerate(rows) if r["replay"]["families"]]
    silent = [(i, r) for i, r in enumerate(rows) if not r["replay"]["families"]]
    drawn = random.Random(SEED).sample(silent, SILENT_DRAW)

    sample = sorted(fires + drawn, key=lambda p: p[0])
    payload = [{"id": i, "text": r["text"]} for i, r in sample]
    random.Random(SEED + 1).shuffle(payload)

    shards = [payload[i : i + SHARD] for i in range(0, len(payload), SHARD)]
    for n, chunk in enumerate(shards):
        with shard_path(n).open("w", encoding="utf-8") as fh:
            json.dump({"shard": n, "rows": chunk}, fh, ensure_ascii=False, indent=1)

    with shard_path(99).open("w", encoding="utf-8") as fh:
        json.dump({"shard": 99, "rows": payload[:OVERLAP]}, fh, ensure_ascii=False, indent=1)

    index = {
        "seed": SEED,
        "bench": str(bench),
        "strata": {"fires": len(fires), "silent_total": len(silent), "silent_drawn": len(drawn)},
        "sample": len(payload),
        "shards": {str(n): len(c) for n, c in enumerate(shards)},
        "overlap_shard": {"id": 99, "duplicates": "shard 00", "rows": OVERLAP},
    }
    with (HERE / "ending_sample_index.json").open("w", encoding="utf-8") as fh:
        json.dump(index, fh, ensure_ascii=False, indent=1)

    print(f"{len(payload)} rows sampled ({len(fires)} fires + {len(drawn)} silent), seed {SEED}")
    for n, c in enumerate(shards):
        print(f"  shard {n:02d}  {len(c):3d} rows  {shard_path(n).name}")
    print(f"  shard 99  {OVERLAP:3d} rows  {shard_path(99).name}  (re-label of shard 00)")


if __name__ == "__main__":
    main()
