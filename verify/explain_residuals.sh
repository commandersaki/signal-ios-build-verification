#!/bin/bash
# Account for every difference between an App Store app and a local build, file by file.
# Complements compare_build.sh (which covers strings/symbols/functions of the 5 first-party binaries).
# Usage: explain_residuals.sh <reference.app|.ipa> <candidate.app|.ipa> <out_dir>
set -euo pipefail
V="$(cd "$(dirname "$0")" && pwd)"
. "$V/app_path.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
REF="$(app_path "$1" "$TMP/ref")"; CAND="$(app_path "$2" "$TMP/cand")"; OUT="$3"
PY="python3 -I"
mkdir -p "$OUT"/{bytediff,assets}
OUT="$(cd "$OUT" && pwd)"

machos=()
while IFS= read -r -d '' f; do
  [ "$(head -c4 "$f" | xxd -p)" = cffaedfe ] && machos+=("${f#$REF/}")
done < <(find "$REF" -type f -print0)
IFS=$'\n' machos=($(sort <<<"${machos[*]}")); unset IFS

# The App Store ships thin binaries; a fat wrapper in the build (e.g. WebRTC) is reduced to its arm64 slice.
cand_bin() {
  local c="$CAND/$1"
  if lipo -info "$c" 2>/dev/null | grep -q '^Architectures in the fat file'; then
    lipo -thin arm64 "$c" -output "$TMP/$(basename "$1").thin"; echo "$TMP/$(basename "$1").thin"
  else echo "$c"; fi
}

echo "== __TEXT,__text SHA-256 (Apple segedit + shasum)"
for m in "${machos[@]}"; do
  n=$(basename "$m"); c=$(cand_bin "$m")
  segedit "$REF/$m" -extract __TEXT __text "$TMP/$n.a" >/dev/null 2>&1
  segedit "$c" -extract __TEXT __text "$TMP/$n.b" >/dev/null 2>&1
  ha=$(shasum -a 256 "$TMP/$n.a" | cut -d' ' -f1); hb=$(shasum -a 256 "$TMP/$n.b" | cut -d' ' -f1)
  printf "%-24s %s %s %s\n" "$n" "$ha" "$([ "$ha" = "$hb" ] && echo IDENTICAL || echo DIFFERENT)" "$(stat -f%z "$TMP/$n.a")"
done | tee "$OUT/text_sha256.txt"

echo "== whole-binary byte diff (signatures removed), by region"
pairs=()
for m in "${machos[@]}"; do
  n=$(basename "$m"); c=$(cand_bin "$m")
  $PY "$V/bytediff.py" "$REF/$m" "$c" "$OUT/bytediff/$n.json" >/dev/null
  $PY -c "import json,sys; d=json.load(open(sys.argv[1])); print(f\"{sys.argv[2]:24} differing_bytes={d['differing_bytes']:<6} {d['by_region']}\")" "$OUT/bytediff/$n.json" "$n"
  pairs+=("$REF/$m" "$c")
done > "$OUT/bytediff_summary.txt"
cat "$OUT/bytediff_summary.txt"

echo "== header bytes: which load-command field"
$PY "$V/header_fields.py" "${pairs[@]}" | sort | tee "$OUT/header_fields.txt"

echo "== stubs and __const: do differing bytes still resolve to the same targets?"
: > "$OUT/stubs_and_const.txt"
for m in "${machos[@]}"; do
  n=$(basename "$m")
  if $PY -c "import json,sys; r=json.load(open(sys.argv[1]))['by_region']; sys.exit(0 if any(k.startswith('__TEXT,') for k in r) else 1)" "$OUT/bytediff/$n.json"; then
    cp "$REF/$m" "$TMP/$n.ref"; cp "$(cand_bin "$m")" "$TMP/$n.cand"
    codesign --remove-signature "$TMP/$n.ref" "$TMP/$n.cand" 2>/dev/null || true
    { echo "-- $n"; $PY "$V/stub_targets.py" "$TMP/$n.ref" "$TMP/$n.cand"; $PY "$V/got_relptrs.py" "$TMP/$n.ref" "$TMP/$n.cand" | grep -v '^  0x'; } | tee -a "$OUT/stubs_and_const.txt"
  fi
done

echo "== plists: differing keys"
: > "$OUT/plists.txt"
while IFS= read -r -d '' f; do
  r="${f#$REF/}"; [ -f "$CAND/$r" ] || continue
  cmp -s "$f" "$CAND/$r" && continue
  d=$(diff <(plutil -p "$f") <(plutil -p "$CAND/$r") || true)
  [ -n "$d" ] && { echo "-- $r"; echo "$d"; } >> "$OUT/plists.txt"
done < <(find "$REF" -name '*.plist' -not -path '*/_CodeSignature/*' -print0)
grep -c '^-- ' "$OUT/plists.txt" | sed 's/^/plists differing: /'
grep '^[<>]' "$OUT/plists.txt" | sed -E 's/^([<>]) +"([^"]+)".*/\2/' | sort | uniq -c | sort -rn

echo "== loose PNGs that differ: decoded pixels"
: > "$OUT/assets/pngs.txt"
while IFS= read -r -d '' f; do
  r="${f#$REF/}"; [ -f "$CAND/$r" ] && ! cmp -s "$f" "$CAND/$r" && { echo "-- $r"; $PY "$V/pngpixels.py" "$f" "$CAND/$r"; } >> "$OUT/assets/pngs.txt"
done < <(find "$REF" -name '*.png' -print0)
cat "$OUT/assets/pngs.txt"

echo "== asset catalogs: renditions"
: > "$OUT/assets/catalogs.txt"
while IFS= read -r -d '' f; do
  r="${f#$REF/}"; [ -f "$CAND/$r" ] && $PY "$V/assets_compare.py" "$f" "$CAND/$r" "$r" >> "$OUT/assets/catalogs.txt"
done < <(find "$REF" -name '*.car' -print0)
cat "$OUT/assets/catalogs.txt"

echo "== reference app vs its own code signatures"
$PY "$V/signature_pages.py" "$REF" | tee "$OUT/signature_pages.txt"
echo "done: $OUT"
