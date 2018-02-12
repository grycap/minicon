function trim() {
  shopt -s extglob
  local A="${1##+([[:space:]])}"
  A="${A%%+([[:space:]])}"
  shopt -u extglob
  echo "$A"
}
