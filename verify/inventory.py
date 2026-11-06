#!/usr/bin/env python3
"""Inventory every file in an .app bundle: path, size, sha256, kind.

Usage: inventory.py <path/to/X.app> <out.json>
"""
import hashlib
import json
import os
import sys

MACHO_MAGICS = {
    b"\xcf\xfa\xed\xfe",  # MH_MAGIC_64 (little endian)
    b"\xce\xfa\xed\xfe",  # MH_MAGIC
    b"\xca\xfe\xba\xbe",  # FAT_MAGIC
    b"\xca\xfe\xba\xbf",  # FAT_MAGIC_64
}


def kind_of(path, head):
    if head[:4] in MACHO_MAGICS:
        return "macho"
    rel = path.replace(os.sep, "/")
    if "/_CodeSignature/" in "/" + rel or rel.endswith("embedded.mobileprovision"):
        return "signature"
    if rel.endswith(".car"):
        return "assetcatalog"
    if rel.endswith((".nib", ".storyboardc")) or ".storyboardc/" in rel or ".nib/" in rel:
        return "nib"
    if rel.endswith(".plist"):
        return "plist"
    return "resource"


def main(app, out):
    app = os.path.abspath(app)
    files = {}
    for root, dirs, names in os.walk(app):
        dirs.sort()
        for name in sorted(names):
            full = os.path.join(root, name)
            if os.path.islink(full):
                rel = os.path.relpath(full, app)
                files[rel] = {"kind": "symlink", "target": os.readlink(full)}
                continue
            rel = os.path.relpath(full, app)
            h = hashlib.sha256()
            with open(full, "rb") as f:
                head = f.read(4)
                h.update(head)
                for chunk in iter(lambda: f.read(1 << 20), b""):
                    h.update(chunk)
            files[rel] = {
                "kind": kind_of(rel, head),
                "size": os.path.getsize(full),
                "sha256": h.hexdigest(),
            }
    with open(out, "w") as f:
        json.dump({"app": app, "file_count": len(files), "files": files}, f, indent=1, sort_keys=True)
    print(f"{out}: {len(files)} files")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
