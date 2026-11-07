# Sourced by the shell scripts: resolve an argument that is either an .app directory or an .ipa
# to an .app directory. An .ipa is unzipped (Payload/ only) into the given scratch directory.
# Usage: APP="$(app_path <path.app|path.ipa> <scratch_dir>)"
app_path() {
  local in="$1" scratch="$2"
  case "$in" in
    *.ipa)
      local dest="$scratch/$(basename "$in" .ipa)"
      mkdir -p "$dest"
      unzip -q -o "$in" 'Payload/*' -d "$dest"
      local apps=("$dest"/Payload/*.app)
      [ ${#apps[@]} -eq 1 ] && [ -d "${apps[0]}" ] || { echo "expected one Payload/*.app in $in" >&2; return 1; }
      echo "${apps[0]}"
      ;;
    *) (cd "$in" && pwd) ;;
  esac
}
