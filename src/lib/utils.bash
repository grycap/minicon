function trim() {
  shopt -s extglob
  local A="${1##+([[:space:]])}"
  A="${A%%+([[:space:]])}"
  shopt -u extglob
  echo "$A"
}

function build_cmdline() {
  local SHCMDLINE=""
  while [ $# -gt 0 ]; do
    if [ "$1" == "&&" -o "$1" == ">" -o "$1" == ">>" -o "$1" == "2>" -o "$1" == "2>>" -o "$1" == "<" -o "$1" == "<<" ]; then
      SHCMDLINE="${SHCMDLINE} $1"
    else
      SHCMDLINE="${SHCMDLINE} \"$1\""
    fi
    shift
  done
  echo "$SHCMDLINE"
}