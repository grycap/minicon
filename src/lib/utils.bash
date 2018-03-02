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
    if [ "$1" == "|" -o "$1" == "&&" -o "$1" == ">" -o "$1" == ">>" -o "$1" == "2>" -o "$1" == "2>>" -o "$1" == "<" -o "$1" == "<<" ]; then
      SHCMDLINE="${SHCMDLINE} $1"
    else
      SHCMDLINE="${SHCMDLINE} \"$1\""
    fi
    shift
  done
  echo "$SHCMDLINE"
}

function arrayze_cmd() {
  # This function creates an array of parameters from a commandline. The special
  # function of this function is that sometimes parameters are between quotes and the
  # common space-separation is not valid. This funcion solves the problem of quotes and
  # then a commandline can be invoked as "${ARRAY[@]}"
  local AN="$1"
  local _CMD="$2"
  local R n=0
  while read R; do
    read ${AN}[$n] <<< "$R"
    n=$((n+1))
  done < <(printf "%s\n" "$_CMD" | xargs -n 1 printf "%s\n")
}

function lines_to_array() {
  local AN="$1"
  local LINES="$2"
  local L
  local n=0
  while read L; do
    read ${AN}[$n] <<< "$L"
    n=$((n+1))
  done <<< "$LINES"
}