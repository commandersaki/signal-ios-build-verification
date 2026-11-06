#!/usr/bin/env python3
"""Compare decoded pixels of two PNGs, including Apple CgBI ("crushed") PNGs.

CgBI PNGs use raw deflate (no zlib header) and BGRA/BGR order; both files are
decoded the same way, so channel order doesn't matter for an equality check.
Reports whether the decoded scanlines are identical and, if not, how many
pixels differ and by how much.

Usage: pngpixels.py <a.png> <b.png>
"""
import struct
import sys
import zlib


def decode(path):
    d = open(path, "rb").read()
    o, idat, cgbi, ihdr = 8, b"", False, None
    while o < len(d):
        n, t = struct.unpack(">I4s", d[o:o + 8])
        body = d[o + 8:o + 8 + n]
        if t == b"CgBI":
            cgbi = True
        elif t == b"IHDR":
            ihdr = struct.unpack(">IIBBBBB", body)
        elif t == b"IDAT":
            idat += body
        o += 12 + n
    raw = zlib.decompress(idat, -15 if cgbi else 15)
    w, h, depth, ctype = ihdr[:4]
    bpp = {2: 3, 6: 4, 0: 1, 4: 2}[ctype] * depth // 8
    stride = w * bpp
    rows, prev = [], bytearray(stride)
    for y in range(h):
        f = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1:
                line[i] = (line[i] + a) & 0xFF
            elif f == 2:
                line[i] = (line[i] + b) & 0xFF
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 0xFF
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 0xFF
        rows.append(bytes(line))
        prev = line
    return (w, h, bpp), b"".join(rows)


def main(a, b):
    (wa, ha, ba), pa = decode(a)
    (wb, hb, bb), pb = decode(b)
    if (wa, ha, ba) != (wb, hb, bb):
        print(f"DIFFERENT GEOMETRY {wa}x{ha}x{ba} vs {wb}x{hb}x{bb}")
        return
    diff_px = sum(1 for i in range(0, len(pa), ba) if pa[i:i + ba] != pb[i:i + ba])
    max_delta = max((abs(x - y) for x, y in zip(pa, pb)), default=0)
    print(f"{wa}x{ha} bpp={ba}: pixels identical={pa == pb} differing_pixels={diff_px}/{wa * ha} max_channel_delta={max_delta}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(*sys.argv[1:])
