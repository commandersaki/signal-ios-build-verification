#!/usr/bin/env python3
"""Byte-compare two Mach-Os after removing code signatures; map diffs to sections.

Signatures are removed with Apple's `codesign --remove-signature` on temp copies.
Every differing byte is attributed to a (segment, section) or a load command,
so "identical except X" is a measured statement.

Usage: bytediff.py <a> <b> <out.json>
"""
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
from collections import Counter


def layout(data):
    _, _, _, _, ncmds, sizeofcmds, _, _ = struct.unpack_from("<IiiIIIII", data, 0)
    regions = [(0, 32 + sizeofcmds, "mach_header+load_commands")]
    off = 32
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", data, off)
        if cmd == 0x19:
            seg = data[off + 8:off + 24].rstrip(b"\0").decode()
            fileoff, filesize = struct.unpack_from("<QQ", data, off + 40)
            nsects = struct.unpack_from("<I", data, off + 64)[0]
            s = off + 72
            for _ in range(nsects):
                sect = data[s:s + 16].rstrip(b"\0").decode()
                size = struct.unpack_from("<Q", data, s + 40)[0]
                offset, = struct.unpack_from("<I", data, s + 48)
                if offset:
                    regions.append((offset, offset + size, f"{seg},{sect}"))
                s += 80
            if seg == "__LINKEDIT":
                regions.append((fileoff, fileoff + filesize, "__LINKEDIT"))
        off += cmdsize
    return regions


def region_of(regions, pos):
    best = None
    for lo, hi, name in regions:
        if lo <= pos < hi and (best is None or hi - lo < best[1] - best[0]):
            best = (lo, hi, name)
    return best[2] if best else "unmapped"


def stripped(path, d):
    dst = os.path.join(d, os.path.basename(path) + f".{abs(hash(path))}")
    shutil.copy(path, dst)
    subprocess.run(["codesign", "--remove-signature", dst], capture_output=True)
    return open(dst, "rb").read()


def main(a, b, out):
    with tempfile.TemporaryDirectory() as d:
        da, db = stripped(a, d), stripped(b, d)
    regions = layout(da)
    n = min(len(da), len(db))
    diffs = Counter()
    first = {}
    for i in range(n):
        if da[i] != db[i]:
            r = region_of(regions, i)
            diffs[r] += 1
            first.setdefault(r, i)
    res = {"a": a, "b": b, "a_size_unsigned": len(da), "b_size_unsigned": len(db),
           "identical": da == db, "differing_bytes": sum(diffs.values()),
           "by_region": dict(diffs), "first_offset": {k: hex(v) for k, v in first.items()}}
    json.dump(res, open(out, "w"), indent=1)
    print(f"{os.path.basename(a)}: unsigned sizes {len(da)} vs {len(db)}, identical={da == db}, "
          f"differing bytes={sum(diffs.values())} {dict(diffs)}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
