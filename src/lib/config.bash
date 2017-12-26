# Reads a configuration file and set its variables (removes comments, blank lines, trailing spaces, etc. and
# then reads KEY=VALUE settings)
function readconf() {
  local _CONF_FILE=$1
  local _CURRENT_SECTION
  local _TXT_CONF
  local _CURRENT_KEY _CURRENT_VALUE

  # If the config file does not exist return failure
  if [ ! -e "$_CONF_FILE" ]; then
    return 1
  fi

  # First we read the config file
  _TXT_CONF="$(cat "$_CONF_FILE" | sed 's/#.*//g' | sed 's/^[ \t]*//g' | sed 's/[ \t]*$//g' | sed '/^$/d')"

  # Let's read the lines
  while read L; do
    if [[ "$L" =~ ^\[.*\]$ ]]; then
      # If we are reading a section, let's see if it is applicable to us
      _CURRENT_SECTION="${L:1:-1}"
    else
      IFS='=' read _CURRENT_KEY _CURRENT_VALUE <<< "$L"
      _CURRENT_VALUE="$(echo "$_CURRENT_VALUE" | envsubst)"
      read -d '\0' "$_CURRENT_KEY" <<< "${_CURRENT_VALUE}"
    fi
  done <<< "$_TXT_CONF"
  return 0
}