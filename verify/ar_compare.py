#!/usr/bin/env python3
"""Compare two static libraries (BSD ar archives) member by member.

Members are matched by name (Rust/cc object names embed content-independent hashes of
crate metadata, so equal names mean the same compilation unit). For each pair, reports
whether the bytes are identical; for differing Mach-O objects, which sections differ;
for differing LLVM bitcode, the size difference.

Usage: ar_compare.py <reference.a> <candidate.a> [out.json]
"""
import hashlib, json, struct, sys
from collections import Counter


def members(path):
    d = open(path, "rb").read()
    assert d[:8] == b"!<arch>\n", path
    o, out = 8, []
    while o < len(d):
        h = d[o:o + 60]; name = h[:16].decode().strip(); size = int(h[48:58]); o += 60
        data = d[o:o + size]
        if name.startswith("#1/"):
            n = int(name[3:]); name = data[:n].rstrip(b"\0").decode(); data = data[n:]
        out.append((name, data))
        o += size + (size & 1)
    return out


def kind(b):
    return "bitcode" if b[:4] in (b"\xde\xc0\x17\x0b", b"BC\xc0\xde") else "macho" if b[:4] == b"\xcf\xfa\xed\xfe" else "other"


def sections(b):
    ncmds = struct.unpack_from("<I", b, 16)[0]; off = 32; out = {}
    for _ in range(ncmds):
        cmd, sz = struct.unpack_from("<II", b, off)
        if cmd == 0x19:
            nsects = struct.unpack_from("<I", b, off + 64)[0]; s = off + 72
            for _ in range(nsects):
                sect = b[s:s + 16].rstrip(b"\0").decode(); seg = b[s + 16:s + 32].rstrip(b"\0").decode()
                size, offset = struct.unpack_from("<QI", b, s + 40)
                out[f"{seg},{sect}"] = hashlib.sha256(b[offset:offset + size]).hexdigest() if offset else f"zerofill:{size}"
                s += 80
        off += sz
    return out


def main(ref, cand, out=None):
    a, b = members(ref), members(cand)
    da = {n: x for n, x in a if n != "__.SYMDEF"}; db = {n: x for n, x in b if n != "__.SYMDEF"}
    res = {"ref": ref, "cand": cand, "ref_members": len(da), "cand_members": len(db),
           "only_ref": sorted(set(da) - set(db)), "only_cand": sorted(set(db) - set(da)),
           "identical": 0, "differ": {}}
    kinds = Counter()
    for n in sorted(set(da) & set(db)):
        x, y = da[n], db[n]
        if x == y:
            res["identical"] += 1; kinds[kind(x) + " identical"] += 1; continue
        k = kind(x); kinds[k + " differ"] += 1
        info = {"kind": k, "ref_size": len(x), "cand_size": len(y)}
        if k == "macho" and kind(y) == "macho":
            sa, sb = sections(x), sections(y)
            info["sections_differ"] = sorted(s for s in set(sa) | set(sb) if sa.get(s) != sb.get(s))
        res["differ"][n] = info
    res["by_kind"] = dict(kinds)
    symdef = [x for n, x in a if n == "__.SYMDEF"], [x for n, x in b if n == "__.SYMDEF"]
    res["symdef_identical"] = symdef[0] == symdef[1]
    res["whole_file_identical"] = open(ref, "rb").read() == open(cand, "rb").read()
    print(f"members: ref={len(da)} cand={len(db)}; only in ref={len(res['only_ref'])}, only in cand={len(res['only_cand'])}")
    print(f"identical members: {res['identical']}; differing: {len(res['differ'])}; by kind: {dict(kinds)}")
    print(f"symbol table identical: {res['symdef_identical']}; whole file identical: {res['whole_file_identical']}")
    secs = Counter(s for v in res["differ"].values() for s in v.get("sections_differ", []))
    if secs: print("differing sections (count of members):", dict(secs.most_common(12)))
    if out: json.dump(res, open(out, "w"), indent=1)


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    main(*sys.argv[1:])
