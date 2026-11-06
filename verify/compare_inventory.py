#!/usr/bin/env python3
"""Compare two inventory.json files. Emits JSON summary + per-file detail.

Usage: compare_inventory.py <a.json> <b.json> <out.json>
"""
import json
import sys
from collections import Counter


def main(a_path, b_path, out):
    a = json.load(open(a_path))["files"]
    b = json.load(open(b_path))["files"]
    only_a = sorted(set(a) - set(b))
    only_b = sorted(set(b) - set(a))
    common = sorted(set(a) & set(b))
    same, differ = [], []
    for p in common:
        ha, hb = a[p].get("sha256", a[p].get("target")), b[p].get("sha256", b[p].get("target"))
        (same if ha == hb else differ).append(p)

    def by_kind(paths, src):
        return dict(Counter(src[p]["kind"] for p in paths))

    result = {
        "a": a_path,
        "b": b_path,
        "counts": {
            "a_files": len(a),
            "b_files": len(b),
            "common": len(common),
            "identical": len(same),
            "differ": len(differ),
            "only_in_a": len(only_a),
            "only_in_b": len(only_b),
        },
        "identical_by_kind": by_kind(same, a),
        "differ_by_kind": by_kind(differ, a),
        "only_in_a_by_kind": by_kind(only_a, a),
        "only_in_b_by_kind": by_kind(only_b, b),
        "differ": differ,
        "only_in_a": only_a,
        "only_in_b": only_b,
    }
    with open(out, "w") as f:
        json.dump(result, f, indent=1)
    print(json.dumps(result["counts"]))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
