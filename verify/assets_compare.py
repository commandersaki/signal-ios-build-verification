#!/usr/bin/env python3
"""Compare two compiled asset catalogs (.car) rendition by rendition.

Uses Apple's `assetutil --info` on each catalog. Renditions are keyed by their
identity (type, name, rendition name, scale, idiom, appearance, gamut, size,
encoding) and compared by SHA1Digest. Each differing rendition is classified:
an app icon, a packed atlas, a raster whose stored vector source is identical
in both catalogs, a vector source itself, or other.

Usage: assets_compare.py <ref.car> <cand.car> <label>
"""
import json
import subprocess
import sys
from collections import defaultdict

FIELDS = ("AssetType", "Name", "RenditionName", "Scale", "Idiom", "Appearance",
          "DisplayGamut", "Dimension1", "PixelWidth", "PixelHeight", "Encoding")


def info(car):
    out = subprocess.run(["xcrun", "--sdk", "iphoneos", "assetutil", "--info", car],
                         capture_output=True, text=True, check=True).stdout
    return [x for x in json.loads(out) if "AssetType" in x]


def ident(x):
    return tuple(str(x.get(k)) for k in FIELDS)


def main(ref, cand, label):
    da = {ident(x): x for x in info(ref)}
    db = {ident(x): x for x in info(cand)}
    common = set(da) & set(db)
    diff = [k for k in common if da[k]["SHA1Digest"] != db[k]["SHA1Digest"]]
    only_a = [k for k in da if k not in db]
    only_b = [k for k in db if k not in da]
    vec = defaultdict(dict)
    for side, d in (("a", da), ("b", db)):
        for x in d.values():
            if x["AssetType"] == "Vector":
                vec[x["Name"]][side] = x["SHA1Digest"]
    cats = defaultdict(list)
    for k in diff:
        t, n = k[0], k[1]
        if n.startswith("AppIcon"):
            cats["app icon"].append(k)
        elif t == "PackedImage":
            cats["packed atlas (raster)"].append(k)
        elif t == "Vector":
            cats["VECTOR SOURCE"].append(k)
        elif n in vec and vec[n].get("a") == vec[n].get("b"):
            cats["raster of identical vector source"].append(k)
        else:
            cats["OTHER"].append(k)
    print(f"{label}: renditions ref={len(da)} cand={len(db)}; same identity={len(common)}; "
          f"identical={len(common) - len(diff)}; digest differs={len(diff)}; ref-only={len(only_a)}; cand-only={len(only_b)}")
    for c, l in sorted(cats.items()):
        print(f"   {c}: {len(l)} {sorted({k[1] for k in l})}")
    # Unmatched renditions: report by name/type/idiom/scale/size, ignoring rendition file names
    # (actool embeds a random UUID, process ID and timestamp in app-icon rendition names).
    loose = lambda ks, d: sorted((d[k].get("Name"), d[k]["AssetType"], d[k].get("Idiom"), d[k].get("Scale"),
                                  d[k].get("PixelWidth")) for k in ks)
    la, lb = loose(only_a, da), loose(only_b, db)
    rest_b = list(lb)
    for x in la:
        if x in rest_b:
            rest_b.remove(x)
    print(f"   ref-only renditions without a same-name/type/idiom/scale/size counterpart: {len(la) - (len(lb) - len(rest_b))}")
    print(f"   cand-only renditions without a counterpart: {len(rest_b)} "
          f"{sorted({(n, t, i, s, w) for n, t, i, s, w in rest_b})[:4]}{' ...' if len(rest_b) > 4 else ''}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
