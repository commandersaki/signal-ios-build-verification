#!/usr/bin/env python3
"""Check a decrypted app's binaries against their own code signatures.

The CodeDirectory page hashes cover the bytes as shipped (FairPlay-encrypted),
so after decryption only pages overlapping the encrypted range, plus the page
holding the cryptid flag, may mismatch. This checks every page, then sets cryptid
back to 1 and re-checks, so every page outside the encrypted range must match
exactly what Apple signed.

Usage: signature_pages.py <decrypted.app>
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import validate_decryption as V  # noqa: E402


def main(app):
    nbin = total = ok = inside = outside = outside_after = 0
    for root, _, files in os.walk(app):
        for f in files:
            d = bytearray(open(os.path.join(root, f), "rb").read())
            info = V.macho_info(bytes(d))
            if not info or not info["sig"]:
                continue
            nbin += 1
            cdi = V.sha256_codedirectory(bytes(d), info["sig"])
            page, e = 1 << cdi[5], info["enc"]
            in_enc = lambda i: e and not ((i + 1) * page <= e["cryptoff"] or i * page >= e["cryptoff"] + e["cryptsize"])
            good, bad = V.check_pages(bytes(d), cdi)
            total += good + len(bad)
            ok += good
            inside += sum(1 for i in bad if in_enc(i))
            out = [i for i in bad if not in_enc(i)]
            outside += len(out)
            if e:
                d[e["cryptid_field"]:e["cryptid_field"] + 4] = (1).to_bytes(4, "little")
            _, bad2 = V.check_pages(bytes(d), cdi)
            outside_after += sum(1 for i in out if i in bad2)
    print(f"{nbin} signed Mach-O binaries, {total} code-signature pages: {ok} match as-is; "
          f"{inside} differ inside FairPlay-encrypted ranges (expected: those pages are now decrypted); "
          f"{outside} differ outside them; after restoring cryptid=1, {outside_after} still differ outside them")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
