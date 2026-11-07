"""Name the load-command field of every differing header byte between Mach-O pairs (signatures removed first).

Usage: header_fields.py <ref> <cand> [<ref> <cand> ...]
"""
import sys, struct, subprocess, tempfile, shutil, os
NAMES = {0x19: "LC_SEGMENT_64", 0x1b: "LC_UUID", 0x1d: "LC_CODE_SIGNATURE", 0x32: "LC_BUILD_VERSION"}
SEG = {8: "segname", 24: "vmaddr", 32: "vmsize", 40: "fileoff", 48: "filesize"}
def unsigned(p, tmp):
    q = os.path.join(tmp, os.path.basename(p) + str(len(os.listdir(tmp))))
    shutil.copy(p, q); subprocess.run(["codesign", "--remove-signature", q], check=True, capture_output=True)
    return open(q, "rb").read()
tmp = tempfile.mkdtemp()
for ref, cand in zip(sys.argv[1::2], sys.argv[2::2]):
    a, b = unsigned(ref, tmp), unsigned(cand, tmp)
    ncmds = struct.unpack_from("<I", a, 16)[0]; off = 32; out = {}
    for _ in range(ncmds):
        cmd, sz = struct.unpack_from("<II", a, off)
        for i in range(off, off + sz):
            if a[i] != b[i]:
                rel = i - off
                if cmd == 0x19:
                    seg = a[off+8:off+24].rstrip(b"\0").decode()
                    fld = next((n for o, n in sorted(SEG.items(), reverse=True) if rel >= o), "?")
                    key = f"{seg}.{fld}"
                else:
                    key = NAMES.get(cmd, hex(cmd))
                out[key] = out.get(key, 0) + 1
        off += sz
    print(f"{os.path.basename(ref):24} {out}")
shutil.rmtree(tmp)
