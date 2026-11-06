#!/usr/bin/env python3
"""One-line-per-binary summary of a compare_build.sh output directory.

Usage: summarise.py <out_dir>
"""
import json
import os
import sys

BINS = ["Signal", "SignalServiceKit", "SignalUI", "SignalNSE", "SignalShareExtension"]


def main(out):
    for n in BINS:
        feats = json.load(open(os.path.join(out, "features", f"{n}_diff.json")))["features"]
        funcs = json.load(open(os.path.join(out, "funcs", f"{n}_diff.json")))
        differing = {k: (len(v["only_in_a"]), len(v["only_in_b"]))
                     for k, v in feats.items() if v["only_in_a"] or v["only_in_b"]}
        print(f"{n:22} funcs {funcs['matched_functions']}/{funcs['a_functions']} "
              f"({funcs['func_match_pct_of_a']}%) insns {funcs['insn_match_pct_of_a']}% | "
              f"exports {feats['exports']['a_count']}/{feats['exports']['b_count']} | "
              f"features differing (only_ref, only_cand): {differing or 'none'}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
