"""For every stub in __stubs / __objc_stubs, compare what it resolves to in two builds and count stubs whose bytes differ.

Usage: stub_targets.py <ref> <cand>
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import functions as F
ref, cand = sys.argv[1], sys.argv[2]
R = {}
for p in (ref, cand):
    mo = F.MachO(p)
    R[p] = (mo, F.Resolver(mo, F.load_fixups(p), mo.function_starts()))
ma, ra = R[ref]; mb, rb = R[cand]
for name, step in (("__stubs", 12), ("__objc_stubs", 32)):
    sa, sb = ma.section(name), mb.section(name)
    assert sa[:2] == sb[:2]
    n = diff = same = 0
    for off in range(0, sa[1], step):
        addr = sa[0] + off
        ba, bb = ma.read(addr, step), mb.read(addr, step)
        n += 1
        if ba != bb:
            diff += 1
            same += ra.stubs.get(addr) == rb.stubs.get(addr) and ra.stubs.get(addr) is not None
    labels_equal = sum(ra.stubs.get(sa[0] + o) == rb.stubs.get(sa[0] + o) for o in range(0, sa[1], step))
    print(f"{name}: {n} stubs, {labels_equal} resolve identically; {diff} differ in bytes, of which {same} still resolve to the same target")
