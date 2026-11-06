#!/usr/bin/env python3
"""Compare features of the same binary from two builds (a = reference, b = candidate).

For each feature list, reports multiset overlap and the exact items present in
only one side. Nothing is summarised away: every differing item is in the JSON.

Usage: compare_features.py <a_features.json> <b_features.json> <out.json>
"""
import json
import sys
from collections import Counter


def main(a_path, b_path, out):
    a = json.load(open(a_path))["features"]
    b = json.load(open(b_path))["features"]
    result = {"a": a_path, "b": b_path, "features": {}}
    lines = []
    for key in sorted(set(a) | set(b)):
        ca, cb = Counter(a.get(key, [])), Counter(b.get(key, []))
        only_a, only_b = ca - cb, cb - ca
        common = sum((ca & cb).values())
        total = sum((ca | cb).values())
        sim = common / total if total else 1.0
        result["features"][key] = {
            "a_count": sum(ca.values()),
            "b_count": sum(cb.values()),
            "common": common,
            "similarity": round(sim, 6),
            "only_in_a": sorted(only_a.elements()),
            "only_in_b": sorted(only_b.elements()),
        }
        lines.append(f"{key:28} a={sum(ca.values()):7} b={sum(cb.values()):7} "
                     f"common={common:7} only_a={sum(only_a.values()):6} "
                     f"only_b={sum(only_b.values()):6} sim={sim:.4f}")
    with open(out, "w") as f:
        json.dump(result, f, indent=1)
    print("\n".join(lines))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
