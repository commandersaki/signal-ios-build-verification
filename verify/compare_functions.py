#!/usr/bin/env python3
"""Compare function fingerprints of the same binary from two builds.

a = reference (shipped IPA), b = candidate (our build).
Matching is by normalised-content fingerprint, as a multiset (identical
small functions such as thunks occur many times). Reports what fraction of
a's functions and instructions have an exact counterpart in b, and lists
every unmatched function in both directions, largest first.

Usage: compare_functions.py <a_funcs.json> <b_funcs.json> <out.json>
"""
import json
import sys
from collections import Counter, defaultdict


def main(a_path, b_path, out):
    a = json.load(open(a_path))
    b = json.load(open(b_path))
    ca = Counter(f["fp"] for f in a["functions"])
    cb = Counter(f["fp"] for f in b["functions"])
    remaining = ca & cb  # matched counts per fingerprint

    def split(funcs, budget):
        budget = Counter(budget)
        matched, unmatched = [], []
        for f in funcs:
            if budget[f["fp"]] > 0:
                budget[f["fp"]] -= 1
                matched.append(f)
            else:
                unmatched.append(f)
        return matched, unmatched

    a_m, a_u = split(a["functions"], remaining)
    b_m, b_u = split(b["functions"], remaining)
    ins = lambda fs: sum(f["n_insns"] for f in fs)
    res = {
        "a": a_path, "b": b_path,
        "a_functions": len(a["functions"]), "b_functions": len(b["functions"]),
        "matched_functions": len(a_m),
        "a_insns": ins(a["functions"]), "b_insns": ins(b["functions"]),
        "matched_insns": ins(a_m),
        "func_match_pct_of_a": round(100 * len(a_m) / max(1, len(a["functions"])), 3),
        "insn_match_pct_of_a": round(100 * ins(a_m) / max(1, ins(a["functions"])), 3),
        "unmatched_in_a": sorted(({"addr": hex(f["addr"]), "n_insns": f["n_insns"], "fp": f["fp"]} for f in a_u),
                                 key=lambda x: -x["n_insns"]),
        "unmatched_in_b": sorted(({"addr": hex(f["addr"]), "n_insns": f["n_insns"], "fp": f["fp"]} for f in b_u),
                                 key=lambda x: -x["n_insns"]),
    }
    with open(out, "w") as f:
        json.dump(res, f, indent=1)
    keys = ["a_functions", "b_functions", "matched_functions", "func_match_pct_of_a",
            "a_insns", "b_insns", "matched_insns", "insn_match_pct_of_a"]
    print(" ".join(f"{k}={res[k]}" for k in keys) +
          f" unmatched_a={len(a_u)} unmatched_b={len(b_u)}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
