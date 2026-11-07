#!/bin/bash
# Record inputs and tool versions so every result can be traced and re-run.
# Usage: provenance.sh <ipa_app_dir|app.ipa> <source_repo_dir> <out.txt>
set -u
. "$(cd "$(dirname "$0")" && pwd)/app_path.sh"
APPTMP="$(mktemp -d)"; trap 'rm -rf "$APPTMP"' EXIT
IN="$1"; APP="$(app_path "$1" "$APPTMP")"; SRC="$2"; OUT="$3"
{
  [ "${IN%.ipa}" != "$IN" ] && echo "ipa_file: $(basename "$IN") sha256 $(shasum -a 256 "$IN" | cut -d' ' -f1)"
  echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "macos: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
  echo "xcode: $(xcodebuild -version | tr '\n' ' ')"
  echo "developer_dir: $(xcode-select -p)"
  echo "metal: $(xcrun metal --version 2>/dev/null | head -1)"
  echo "python: $(python3 --version)"
  echo "ipsw: $(ipsw version 2>/dev/null | head -1)"
  echo "radare2: $(radare2 -v 2>/dev/null | head -1)"
  echo "diffoscope: $(diffoscope --version 2>/dev/null)"
  echo
  echo "source_dir: $SRC"
  echo "source_commit: $(git -C "$SRC" rev-parse HEAD)"
  echo "source_describe: $(git -C "$SRC" describe --tags --exact-match 2>/dev/null)"
  echo "source_dirty: $(git -C "$SRC" status --porcelain --untracked-files=no | wc -l | tr -d ' ') modified tracked files"
  echo "pods_commit: $(git -C "$SRC/Pods" rev-parse HEAD 2>/dev/null)"
  echo
  echo "ipa_app: $APP"
  echo "ipa_version: $(plutil -extract CFBundleShortVersionString raw "$APP/Info.plist") ($(plutil -extract CFBundleVersion raw "$APP/Info.plist"))"
  echo "ipa_built_with: Xcode $(plutil -extract DTXcode raw "$APP/Info.plist") build $(plutil -extract DTXcodeBuild raw "$APP/Info.plist")"
  echo
  echo "ipa_macho_sha256:"
  find "$APP" -type f -print0 | while IFS= read -r -d '' f; do
    if [ "$(head -c4 "$f" | xxd -p)" = "cffaedfe" ]; then
      echo "  $(shasum -a 256 "$f" | cut -d' ' -f1)  ${f#$APP/}"
    fi
  done | sort -k2
} > "$OUT"
echo "wrote $OUT"
