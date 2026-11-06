#!/usr/bin/env python3
"""Cross-check our own section-string parser against Apple's segedit.

For each string section, extract its raw bytes with `segedit -extract SEG SECT`
(Apple's Mach-O code locates the section, not ours), split on NUL, and compare
the string multiset to what macho_features.py extracted. Any disagreement means
one of the two is wrong and results from this layer are not trusted.

Usage: crosscheck_strings.py <binary> <features.json>
"""
import json
import os
import subprocess
import sys
import tempfile
from collections import Counter


def segedit_strings(binary, seg, sect):
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, "sect.bin")
        r = subprocess.run(["segedit", binary, "-extract", seg, sect, out],
                           capture_output=True, text=True)
        if r.returncode != 0 or not os.path.exists(out):
            return None, r.stderr.strip()
        raw = open(out, "rb").read()
    return [p.decode("utf-8", "backslashreplace") for p in raw.split(b"\0") if p], ""


def main(binary, feats_path):
    feats = json.load(open(feats_path))["features"]
    ok = True
    for key, ours in feats.items():
        if not key.startswith("__TEXT,"):
            continue
        seg, sect = key.split(",")
        theirs, err = segedit_strings(binary, seg, sect)
        if theirs is None:
            status = "OK" if not ours else "MISMATCH"
            print(f"{status:8} {key:28} ours={len(ours):7} segedit=absent ({err[:60]})")
            ok &= status == "OK"
            continue
        a, b = Counter(ours), Counter(theirs)
        only_ours, only_ref = a - b, b - a
        status = "OK" if not only_ours and not only_ref else "MISMATCH"
        ok &= status == "OK"
        print(f"{status:8} {key:28} ours={len(ours):7} segedit={len(theirs):7} "
              f"only_ours={sum(only_ours.values())} only_segedit={sum(only_ref.values())}")
        if status != "OK":
            for s in list(only_ours)[:3]:
                print(f"           only_ours:    {s[:100]!r}")
            for s in list(only_ref)[:3]:
                print(f"           only_segedit: {s[:100]!r}")
    print("RESULT:", "PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(*sys.argv[1:])
