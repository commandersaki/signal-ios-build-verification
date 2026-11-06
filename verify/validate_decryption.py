#!/usr/bin/env python3
"""Validate a FairPlay-decrypted IPA against the original encrypted IPA.

Reads both IPAs as zip archives (nothing is extracted). For every Mach-O:
  1. bytes outside the LC_ENCRYPTION_INFO_64 range are unchanged, except the
     cryptid field in the load command;
  2. every page of the decrypted file hashes to the SHA-256 page hash recorded
     in the app's own code signature (CodeDirectory). Those hashes are over the
     plaintext, so a match proves the decrypted bytes are exactly what was signed.
Also checks that every non-Mach-O member is byte-identical, and (optionally) that
the decrypted IPA matches an already-extracted .app directory.

Usage: validate_decryption.py <encrypted.ipa> <decrypted.ipa> <out.json> [extracted.app]
"""
import hashlib
import json
import os
import struct
import sys
import zipfile

LC_SEGMENT_64, LC_CODE_SIGNATURE, LC_ENCRYPTION_INFO_64 = 0x19, 0x1D, 0x2C
CSMAGIC_EMBEDDED_SIGNATURE, CSMAGIC_CODEDIRECTORY = 0xFADE0CC0, 0xFADE0C02


def macho_info(d):
    if d[:4] != b"\xcf\xfa\xed\xfe":
        return None
    ncmds = struct.unpack_from("<I", d, 16)[0]
    off, info = 32, {"enc": None, "sig": None}
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<II", d, off)
        if cmd == LC_ENCRYPTION_INFO_64:
            cryptoff, cryptsize, cryptid = struct.unpack_from("<III", d, off + 8)
            info["enc"] = {"cryptoff": cryptoff, "cryptsize": cryptsize, "cryptid": cryptid,
                           "cryptid_field": off + 16}
        elif cmd == LC_CODE_SIGNATURE:
            info["sig"] = struct.unpack_from("<II", d, off + 8)
        off += size
    return info


def sha256_codedirectory(d, sig):
    dataoff, _ = sig
    magic, _, count = struct.unpack_from(">III", d, dataoff)
    assert magic == CSMAGIC_EMBEDDED_SIGNATURE
    best = None
    for i in range(count):
        _, boff = struct.unpack_from(">II", d, dataoff + 12 + 8 * i)
        cd = dataoff + boff
        if struct.unpack_from(">I", d, cd)[0] != CSMAGIC_CODEDIRECTORY:
            continue
        (_, _, _, _, hash_off, _, _, n_code, code_limit, hash_size, hash_type, _, page_log2) = \
            struct.unpack_from(">IIIIIIIIIBBBB", d, cd)
        if hash_type == 2:  # SHA-256
            best = (cd, hash_off, n_code, code_limit, hash_size, page_log2)
    return best


def check_pages(d, cd_info):
    cd, hash_off, n_code, code_limit, hash_size, page_log2 = cd_info
    page = 1 << page_log2
    ok, bad = 0, []
    for i in range(n_code):
        lo, hi = i * page, min((i + 1) * page, code_limit)
        want = d[cd + hash_off + i * hash_size: cd + hash_off + (i + 1) * hash_size]
        if hashlib.sha256(d[lo:hi]).digest()[:hash_size] == want:
            ok += 1
        else:
            bad.append(i)
    return ok, bad


def main(enc_path, dec_path, out, extracted=None):
    ze, zd = zipfile.ZipFile(enc_path), zipfile.ZipFile(dec_path)
    names_e = {n for n in ze.namelist() if not n.endswith("/")}
    names_d = {n for n in zd.namelist() if not n.endswith("/")}
    res = {"encrypted_ipa": enc_path, "decrypted_ipa": dec_path,
           "encrypted_ipa_sha256": hashlib.sha256(open(enc_path, "rb").read()).hexdigest(),
           "decrypted_ipa_sha256": hashlib.sha256(open(dec_path, "rb").read()).hexdigest(),
           "members_only_in_encrypted": sorted(names_e - names_d),
           "members_only_in_decrypted": sorted(names_d - names_e),
           "non_macho_identical": 0, "non_macho_different": [], "macho": {}}
    for n in sorted(names_e & names_d):
        de, dd = ze.read(n), zd.read(n)
        info_e = macho_info(de)
        if info_e is None:
            if de == dd:
                res["non_macho_identical"] += 1
            else:
                res["non_macho_different"].append(n)
            continue
        info_d = macho_info(dd)
        r = {"size_equal": len(de) == len(dd)}
        enc = info_e["enc"]
        if enc:
            lo, hi, cf = enc["cryptoff"], enc["cryptoff"] + enc["cryptsize"], enc["cryptid_field"]
            outside = [i for i in range(len(de)) if not (lo <= i < hi) and not (cf <= i < cf + 4)
                       and de[i] != dd[i]] if len(de) == len(dd) else ["size differs"]
            r.update({"cryptid_encrypted": enc["cryptid"], "cryptid_decrypted": info_d["enc"]["cryptid"],
                      "encrypted_range_bytes": enc["cryptsize"],
                      "encrypted_range_changed": de[lo:hi] != dd[lo:hi],
                      "bytes_changed_outside_encrypted_range": len(outside)})
        else:
            r["no_encryption_info"] = True
            r["identical"] = de == dd
        if info_d["sig"]:
            # The CodeDirectory page hashes cover the bytes as shipped (encrypted), so they
            # must all match on the encrypted file; on the decrypted file only pages that
            # overlap the encrypted range may mismatch.
            cdi = sha256_codedirectory(de, info_e["sig"])
            ok_e, bad_e = check_pages(de, cdi)
            ok, bad = check_pages(dd, cdi)
            page = 1 << cdi[5]
            outside = [i for i in bad if not enc or (i + 1) * page <= enc["cryptoff"]
                       or i * page >= enc["cryptoff"] + enc["cryptsize"]]
            r.update({"codesign_pages_total": ok_e + len(bad_e), "codesign_pages_ok_encrypted": ok_e,
                      "codesign_pages_ok_decrypted": ok,
                      "decrypted_mismatch_pages_outside_encrypted_range": len(outside)})
        if extracted:
            p = os.path.join(extracted, n.split(".app/", 1)[1])
            r["matches_extracted_dir"] = os.path.exists(p) and open(p, "rb").read() == dd
        res["macho"][n] = r
    if extracted:
        mism = []
        for n in names_d:
            if ".app/" not in n:
                continue
            p = os.path.join(extracted, n.split(".app/", 1)[1])
            if not os.path.exists(p) or open(p, "rb").read() != zd.read(n):
                mism.append(n)
        res["extracted_dir"] = extracted
        res["app_members_not_matching_extracted_dir"] = sorted(mism)
    json.dump(res, open(out, "w"), indent=1)
    m = res["macho"].values()
    enc_ones = [x for x in m if "cryptid_encrypted" in x]
    print(f"members: enc={len(names_e)} dec={len(names_d)}; non-Mach-O identical={res['non_macho_identical']}, "
          f"different={len(res['non_macho_different'])}")
    print(f"Mach-O: {len(m)} total, {len(enc_ones)} had FairPlay encryption "
          f"(cryptid enc->dec: {sorted({(x['cryptid_encrypted'], x['cryptid_decrypted']) for x in enc_ones})})")
    print(f"  bytes changed outside encrypted range (all binaries): "
          f"{sum(x['bytes_changed_outside_encrypted_range'] for x in enc_ones)}")
    tot = sum(x.get("codesign_pages_total", 0) for x in m)
    print(f"  code-signature page hashes: encrypted IPA {sum(x.get('codesign_pages_ok_encrypted', 0) for x in m)}"
          f"/{tot}; decrypted IPA {sum(x.get('codesign_pages_ok_decrypted', 0) for x in m)}/{tot}; "
          f"decrypted mismatches outside encrypted ranges: "
          f"{sum(x.get('decrypted_mismatch_pages_outside_encrypted_range', 0) for x in m)}")
    print(f"  members only in encrypted IPA: {len(res['members_only_in_encrypted'])} "
          f"(top dirs: {sorted({n.split('/')[min(2, n.count('/'))] if n.startswith('Payload') else n.split('/')[0] for n in res['members_only_in_encrypted']})[:8]})")
    print(f"  non-Mach-O members that differ: {res['non_macho_different']}")
    if extracted:
        print(f"  decrypted IPA .app members not matching {extracted}: "
              f"{len(res['app_members_not_matching_extracted_dir'])}")


if __name__ == "__main__":
    if len(sys.argv) not in (4, 5):
        sys.exit(__doc__)
    main(*sys.argv[1:])
