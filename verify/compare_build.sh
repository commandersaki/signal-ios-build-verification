#!/bin/bash
# Run every comparison layer for one (reference app, candidate app) pair.
# Usage: compare_build.sh <reference.app> <candidate.app> <out_dir>
set -euo pipefail
REF="$1"; CAND="$2"; OUT="$3"
V="$(cd "$(dirname "$0")" && pwd)"
PY="python3 -I"
mkdir -p "$OUT"/{features,funcs,crosscheck}

# Binaries built from this repo's source. Third-party frameworks are compared by inventory/hash.
BINS=(
  Signal
  Frameworks/SignalServiceKit.framework/SignalServiceKit
  Frameworks/SignalUI.framework/SignalUI
  PlugIns/SignalNSE.appex/SignalNSE
  PlugIns/SignalShareExtension.appex/SignalShareExtension
)

echo "== inventory"
$PY "$V/inventory.py" "$REF" "$OUT/inventory_ref.json"
$PY "$V/inventory.py" "$CAND" "$OUT/inventory_cand.json"
$PY "$V/compare_inventory.py" "$OUT/inventory_ref.json" "$OUT/inventory_cand.json" "$OUT/inventory_diff.json"

for b in "${BINS[@]}"; do
  n=$(basename "$b")
  echo "== $n: features"
  for side in ref cand; do
    app=$REF; [ $side = cand ] && app=$CAND
    $PY "$V/macho_features.py" "$app/$b" "$OUT/features/${n}_$side.json" > /dev/null
    $PY "$V/crosscheck_strings.py" "$app/$b" "$OUT/features/${n}_$side.json" > "$OUT/crosscheck/${n}_$side.txt" \
      || { echo "CROSSCHECK FAILED for $side $n (see $OUT/crosscheck/${n}_$side.txt)"; exit 1; }
  done
  $PY "$V/compare_features.py" "$OUT/features/${n}_ref.json" "$OUT/features/${n}_cand.json" "$OUT/features/${n}_diff.json"
  echo "== $n: functions"
  $PY "$V/functions.py" "$REF/$b" "$OUT/funcs/${n}_ref.json" --dump-dir "$OUT/funcs/${n}_ref_dump" > /dev/null
  $PY "$V/functions.py" "$CAND/$b" "$OUT/funcs/${n}_cand.json" --dump-dir "$OUT/funcs/${n}_cand_dump" > /dev/null
  $PY "$V/compare_functions.py" "$OUT/funcs/${n}_ref.json" "$OUT/funcs/${n}_cand.json" "$OUT/funcs/${n}_diff.json"
done
echo "done: $OUT"
