"""Explain differing bytes in two unsigned Mach-Os: count those in LC_UUID, and resolve each differing
int32 relative pointer in __TEXT,__const through the GOT, checking both builds point at the same target.

Usage: got_relptrs.py <ref.unsigned> <cand.unsigned>
"""
import sys, struct
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import functions as F
ref, cand = sys.argv[1], sys.argv[2]
A, B = F.MachO(ref), F.MachO(cand)
a, b = A.data, B.data
assert len(a) == len(b)
diffs = [i for i in range(len(a)) if a[i] != b[i]]
ncmds = struct.unpack_from('<I', a, 16)[0]; off = 32; uuid = None
for _ in range(ncmds):
    cmd, sz = struct.unpack_from('<II', a, off)
    if cmd == 0x1b: uuid = (off + 8, off + 24)
    off += sz
hdr = [i for i in diffs if i < off]
print(f'header: {len(hdr)} differing bytes; {sum(uuid[0] <= i < uuid[1] for i in hdr)} in LC_UUID; others at {[hex(i) for i in hdr if not uuid[0] <= i < uuid[1]]}')
def f2v(mo, o):
    for vmaddr, vmsize, fileoff, filesize, _ in mo.segments:
        if fileoff <= o < fileoff + filesize: return vmaddr + o - fileoff
def got_sym(mo, fx, addr):
    s = mo.section_at(addr)
    return s, fx.get(addr)
fa, fb = F.load_fixups(ref), F.load_fixups(cand)
words = sorted({i - (f2v(A, i) % 4) for i in diffs if A.section_at(f2v(A, i) or 0) == ('__TEXT', '__const')})
same = 0
for w in words:
    va = f2v(A, w)
    ra, rb = struct.unpack_from('<i', a, w)[0], struct.unpack_from('<i', b, w)[0]
    # Swift relative indirectable pointer: low bit set means "indirect via GOT"
    ta, tb = va + (ra & ~1), va + (rb & ~1)
    sa, sb = got_sym(A, fa, ta), got_sym(B, fb, tb)
    ok = sa[1] == sb[1] and sa[1] is not None
    same += ok
    print(f'  {va:#x}: {ra:#x}->{sa[0]} {sa[1]}   |   {rb:#x}->{sb[0]} {sb[1]}   {"SAME TARGET" if ok else "DIFFERENT"}')
print(f'__const words differing: {len(words)}, resolving to the same symbol through the GOT: {same}')
