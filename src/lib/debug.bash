function p_errfile() {
  if [ "$LOGFILE" == "" ]; then
    echo "$@" >&2
  else
    touch -f "$LOGFILE"
    if [ $? -eq 0 ]; then
      echo "$@" >> "$LOGFILE"
    fi
  fi
}

function p_error() {
  local O_STR="[ERROR] $LOGGER $(date +%Y.%m.%d-%X) $@"
  p_errfile "$O_STR"
}

function p_warning() {
  local O_STR="[WARNING] $LOGGER $(date +%Y.%m.%d-%X) $@"
  p_errfile "$O_STR"
}

function p_info() {
  local L
  if [ "$VERBOSE" == "true" ]; then
    local TS="$(date +%Y.%m.%d-%X)"
    while read L; do
      p_errfile "[INFO] $LOGGER $TS $@"
    done <<< "$@"
  fi
}

function p_out() {
  if [ "$QUIET" != "true" ]; then
    while read L; do
      echo "$@"
    done <<< "$@"
  fi
}

function p_debug() {
  local L
  if [ "$DEBUG" == "true" ]; then
    local TS="$(date +%Y.%m.%d-%X)"
    while read L; do
      p_errfile "[DEBUG] $LOGGER $TS $L"
    done <<< "$@"
  fi
}

function set_logger() {
  if [ "$1" != "" ]; then
    LOGGER="[$1]"
  else
    LOGGER=
  fi
}

function finalize() {
  # Finalizes the execution of the this script and shows an error (if provided)
  local ERR=$1
  shift
  local COMMENT=$@
  [ "$ERR" == "" ] && ERR=0
  [ "$COMMENT" != "" ] && p_error "$COMMENT"
  if [ "$KEEPTEMPORARY" != "true" ]; then
    p_debug removing temporary folder "$TMPDIR"
    rm -rf "$TMPDIR"
  fi  
  exit $ERR
}