#!/usr/bin/env python3
"""Extract comparable features from a thin arm64 Mach-O.

Own parser for string sections (independent of otool/ipsw), plus Apple's
nm/otool for symbols and linked libraries. Every feature is a sorted list of
strings so two builds can be compared as sets/multisets.

Usage: macho_features.py <binary> <out.json>
"""
import json
import struct
import subprocess
import sys

# (segment, section) pairs that hold NUL-terminated strings.
STRING_SECTIONS = [
    ("__TEXT", "__cstring"),
    ("__TEXT", "__objc_classname"),
    ("__TEXT", "__objc_methname"),
    ("__TEXT", "__objc_methtype"),
    ("__TEXT", "__swift5_reflstr"),
    ("__TEXT", "__oslogstring"),
]

LC_SEGMENT_64 = 0x19
MH_MAGIC_64 = 0xFEEDFACF


def parse_sections(data):
    magic, cputype, _, _, ncmds, _, _, _ = struct.unpack_from("<IiiIIIII", data, 0)
    if magic != MH_MAGIC_64:
        raise SystemExit(f"not a thin 64-bit Mach-O (magic {magic:#x})")
    off = 32
    sections = {}
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", data, off)
        if cmd == LC_SEGMENT_64:
            nsects = struct.unpack_from("<I", data, off + 64)[0]
            s = off + 72
            for _ in range(nsects):
                sectname = data[s:s + 16].rstrip(b"\0").decode()
                segname = data[s + 16:s + 32].rstrip(b"\0").decode()
                addr, size, offset = struct.unpack_from("<QQI", data, s + 32)
                sections[(segname, sectname)] = (offset, size)
                s += 80
        off += cmdsize
    return sections


def section_strings(data, offset, size):
    raw = data[offset:offset + size]
    out = []
    for piece in raw.split(b"\0"):
        if piece:
            out.append(piece.decode("utf-8", "backslashreplace"))
    return out


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout


def main(binary, out):
    data = open(binary, "rb").read()
    sections = parse_sections(data)
    feats = {}
    for seg, sect in STRING_SECTIONS:
        key = f"{seg},{sect}"
        if (seg, sect) in sections:
            offset, size = sections[(seg, sect)]
            feats[key] = sorted(section_strings(data, offset, size))
        else:
            feats[key] = []
    feats["section_sizes"] = sorted(f"{s},{n}={sz}" for (s, n), (_, sz) in sections.items())
    feats["exports"] = sorted(set(run(["nm", "-U", "-j", binary]).splitlines()))
    feats["imports"] = sorted(set(run(["nm", "-u", "-j", binary]).splitlines()))
    libs = run(["otool", "-L", binary]).splitlines()[1:]
    feats["linked_libraries"] = sorted(l.strip().split(" (")[0] for l in libs if l.strip())
    with open(out, "w") as f:
        json.dump({"binary": binary, "features": feats}, f, indent=1)
    print(out + ": " + ", ".join(f"{k}={len(v)}" for k, v in feats.items() if k != "section_sizes"))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(*sys.argv[1:])
