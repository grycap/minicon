function plugin_parameter() {
  # Gets the value of a parameter passed to a plugin
  #   the format is: <plugin>:<param1>=<value1>:<param2>=<value2>...
  local PLUGIN="$1"
  local PARAMETER="$2"
  local PARAMS PP PP2 K V

  while read -d ',' PP; do
    if [[ "$PP" =~ ^$PLUGIN\: ]]; then
      PARAMS="${PP:$((${#PLUGIN}+1))}"
      while read -d ':' PP2; do
        IFS='=' read K V <<< "$PP2"
        if [ "$K" == "$PARAMETER" ]; then
          p_debug "found param $K with value $V"
          echo "$V"
        fi
      done <<< "${PARAMS}:"
    fi
  done <<< "${PLUGINS_ACTIVATED},"
  return 1
}

function _linked_file() {
  local L_PATH="$1"

  # Special cases that we do not want to handle
  if [ "$L_PATH" == "." -o "$L_PATH" == ".." ]; then
    echo "$L_PATH"
    return
  fi

  local R_PATH="$(readlink -f -- "$1")"

  # If the actual file (readlink) is not the same than the original file, it can be supposed that
  # the original file had a link at some point in the path but it is not necessarily a link (e.g. 
  # /var/run -> /run ... /var/run/s6 will be /run/r6, but the link is at the middle).
  if [ "$R_PATH" != "" -a "$L_PATH" != "$R_PATH" ]; then

    # If the file itself is a link, we need to create such link
    if [ -h "$L_PATH" ]; then
      local L_DST="$ROOTFS/$(dirname "$L_PATH")"
  
      if [ ! -e "$L_DST/$(basename $L_PATH)" ]; then
        local R_DST="$ROOTFS/$(dirname "$R_PATH")"

        # TODO: need to revise permission when creating this path... permissions for the folder but
        # also the intermediate folders.
        mkdir -p "$L_DST" 2> /dev/null
        local REL_PATH="$(relPath "$L_DST" "$R_DST")"
        p_debug "$L_PATH is a link to $REL_PATH/$(basename $R_PATH)"
        ln -s $REL_PATH/$(basename $R_PATH) $L_DST/$(basename $L_PATH)
      fi
    fi

    if [ -e "$R_PATH" ]; then
      p_debug "$L_PATH -> $R_PATH"
      echo "$R_PATH"
    else
      p_debug "$L_PATH -> ???"
      echo "$L_PATH"
    fi
  else
    echo "$L_PATH"
  fi
}

function PLUGIN_00_link() {
  # If the path is a link to other path, we will create the link and analyze the real path
  local L_PATH="$1"

  local L_PATH="$(_linked_file "$1")"
  if [ "$L_PATH" != "$1" ]; then
    add_command "$L_PATH"
    return 1
  fi
  return 0
}

function PLUGIN_01_which() {
  # This plugin tries to guess whether the command to analize is in the path or not.
  # If the command can be obtained calling which, we'll analyze the actual command and not the short name.
  local S_PATH="$1"
  local W_PATH="$(which $S_PATH)"

  if [ "$W_PATH" != "" -a "$W_PATH" != "$S_PATH" ]; then
    p_debug "$1 is $W_PATH"
    add_command "$W_PATH"
    return 1
  fi
}

function PLUGIN_02_folder() {
  # If it is a folder, just copy it to its location in the new FS
  local S_PATH="$1"

  if [ -d "$S_PATH" ]; then
    p_debug "copying the whole folder $S_PATH"
    copy "$S_PATH"
    return 1
  fi

  return 0
}

function PLUGIN_09_ldd() {
  # Checks the list of dynamic libraries using ldd and copy them to the proper folder
  local S_PATH="$1"
  local LIBS= LIB=
  local COMMAND="$(which -- $S_PATH)"
  local LIB_DIR=
  if [ "$COMMAND" == "" ]; then
    COMMAND="$S_PATH"
  fi

  COMMAND="$(readlink -e $COMMAND)"
  if [ "$COMMAND" == "" ]; then
    p_debug "cannot analize $S_PATH using ldd"
    return 0
  fi

  p_info "inspect command $COMMAND"
  ldd "$COMMAND" > /dev/null 2> /dev/null
  if [ $? -eq 0 ]; then
    LIBS="$(ldd "$COMMAND" | grep -v 'linux-vdso' | grep -v 'statically' | sed 's/^[ \t]*//g' | sed 's/^.* => //g' | sed 's/(.*)//' | sed '/^[ ]*$/d')"
    for LIB in $LIBS; do
      # Here we build the ld config file to add the new paths where the libraries are located
      if [ "$LDCONFIGFILE" != "" ]; then
        LIB_DIR="$(dirname "$LIB")"
        mkdir -p "$ROOTFS/$(dirname $LDCONFIGFILE)"
        echo "$LIB_DIR" >> "$ROOTFS/$LDCONFIGFILE"
      fi
      add_command "$LIB"
    done
  fi

  copy "$COMMAND"
}

function arrayze_cmd() {
  # This function creates an array of parameters from a commandline. The special
  # function of this function is that sometimes parameters are between quotes and the
  # common space-separation is not valid. This funcion solves the problem of quotes and
  # then a commandline can be invoked as "${ARRAY[@]}"
  local AN="$1"
  local _CMD="$2"
  local R n=0
  declare -g -a -n $AN
  while read R; do
    read ${AN}[n] <<< "$R"
    n=$((n+1))
  done < <(printf "%s\n" "$_CMD" | xargs -n 1 printf "%s\n")
}

function analyze_strace_strings() {
  local STRINGS="$1"
  local S _S
  while read S; do
    S="${S:1:-1}"
    if [ "$S" != "!" ]; then
      if [ "$S" != "" -a "${S::1}" != "-" -a -e "$S" ]; then
        _S="$(readlink -e -- ${S})"
        if [ "$_S" != "" -a -e "$_S" ]; then
          if [ -f "$_S" -o -d "$_S" ]; then
            p_debug "file $S was used"
            echo "$S"
          fi
        fi
      fi
    fi
  done <<< "$STRINGS"
}

_ALREADY_STRACED=()

function MARK_straced() {
  _ALREADY_STRACED+=("$1")
}

function already_straced() {
  local i
  for ((i=0;i<${#_ALREADY_STRACED[@]};i=i+1)); do
    if [ "${_ALREADY_STRACED[$i]}" == "$1" ]; then
      return 0
    fi
  done
  return 1
}

function _strace_exec() {  
  if already_straced "${COMMAND[@]}"; then
    p_debug "command ${COMMAND[@]} already straced"
    return
  fi

  MARK_straced "${COMMAND[@]}"

  # Execute the app without any parameter, using strace and see which files does it open 
  local SECONDSSIM=$(plugin_parameter "strace" "seconds")
  if [[ ! $SECONDSSIM =~ ^[0-9]*$ ]]; then
    SECONDSSIM=3
  fi
  if [ "$SECONDSSIM" == "" ]; then
    SECONDSSIM=3
  fi

  p_info "analysing ${COMMAND[@]} using strace and $SECONDSSIM seconds"

  local TMPFILE=$(tempfile)
  {
    timeout -s 9 $SECONDSSIM strace -qq -e file -fF -o "$TMPFILE" "${COMMAND[@]}" > /dev/null 2> /dev/null
  } > /dev/null 2> /dev/null

  # Now we'll inspect the files that the execution has used
  local FUNCTIONS
  local STRINGS
  local L BN

  FUNCTIONS="open|mkdir"
  STRINGS="$(cat "$TMPFILE" | grep -E "($FUNCTIONS)\(" | grep -o '"[^"]*"' | sort -u)"  
  while read L; do
    if [ "$L" != "" ]; then
      BN="$(basename $L)"
      # add_command "$L"
      if [ "${BN::3}" == "lib" -o "${BN: -3}" == ".so" ]; then
        add_command "$L"
      else
        copy "$L"
      fi
    fi
  done <<< "$(analyze_strace_strings "$STRINGS")"

  FUNCTIONS="exec.*"
  STRINGS="$(cat "$TMPFILE" | grep -E "($FUNCTIONS)\(" | grep -o '"[^"]*"' | sort -u)"  
  while read L; do
    [ "$L" != "" ] && add_command "$L"
  done <<< "$(analyze_strace_strings "$STRINGS")"

  rm "$TMPFILE"

  copy "${COMMAND[0]}"
}

function PLUGIN_10_strace() {
  # Execute the app without any parameter, using strace and see which files does it open 

  # A file that contains examples of calls for the commands to be considered (e.g. this is because
  # some commands will not perform any operation if they do not have parameters; e.g. echo)
  local EXECFILE=$(plugin_parameter "strace" "execfile")

  local S_PATH="$1"
  local COMMAND="$(which -- $S_PATH)"
  if [ "$COMMAND" == "" ]; then
    p_debug "cannot analize $S_PATH using strace"
    return 0
  fi

  # Let's see if there is a specific commandline (with parameters) for this command in the file
  local CMDTOEXEC CMDLINE
  if [ -e "$EXECFILE" ]; then
    local L 
    while read L; do
      CMDTOEXEC=
      arrayze_cmd CMDLINE "$L"
      n=0
      while [ $n -lt ${#CMDLINE[@]} ]; do
        if [ "${CMDLINE[$n]}" == "$COMMAND" ]; then
          CMDTOEXEC="$L"
          break
        fi
        n=$((n+1))
      done
      if [ "$CMDTOEXEC" != "" ]; then
        break
      fi
    done < "$EXECFILE"
  fi

  COMMAND=($COMMAND)

  # If there is a specific commandline, we'll use it; otherwise we'll run the command as-is
  if [ "$CMDTOEXEC" != "" ]; then
    p_debug "will run $CMDTOEXEC"
    COMMAND=( ${CMDLINE[@]} )
  fi

  _strace_exec
}

function STRACE_command() {
  local CMDLINE
  local COMMAND

  arrayze_cmd CMDLINE "$1"
  local _PLUGINS_ACTIVATED="${PLUGINS_ACTIVATED}"

  if [ "${CMDLINE[0]}" != "" ]; then
    local S_PATH="${CMDLINE[0]}"
    local OPTIONS="${S_PATH%,*}"
    local N_PATH="${S_PATH##*,}"

    if [ "$N_PATH" != "" -a "$OPTIONS" != "" ]; then
      p_info "specific options to strace: $OPTIONS"
      PLUGINS_ACTIVATED="${PLUGINS_ACTIVATED},strace:${OPTIONS}"
      S_PATH="$N_PATH"
    fi

    COMMAND="$(which -- $S_PATH)"
    if [ "$COMMAND" == "" ]; then
      p_debug "cannot analize $S_PATH using strace"
      return 0
    fi
    CMDLINE[0]="$COMMAND"
  fi
  COMMAND=( ${CMDLINE[@]} )
  _strace_exec

  PLUGINS_ACTIVATED="${_PLUGINS_ACTIVATED}"
}

function PLUGIN_11_scripts() {
  # Checks the output of the invocation to the "file" command and guess whether it is a interpreted script or not
  #  If it is, adds the interpreter to the list of commands to add to the container
  p_debug "trying to guess if $1 is a interpreted script"

  local S_PATH="$(which $1)"
  local ADD_PATHS=

  if [ "$S_PATH" == "" -o ! -x "$S_PATH" ]; then
    p_debug "$1 cannot be executed (if it should, please check the path)"
    return 0
  fi

  local FILE_RES="$(file $S_PATH | grep -o ':.* script')"
  if [ "$FILE_RES" == "" ]; then
    p_debug "$S_PATH is not recognised as a executable script"
    return 0
  fi

  FILE_RES="${FILE_RES:2:-7}"
  FILE_RES="${FILE_RES,,}"
  local SHELL_EXEC=
  local SHBANG_LINE=$(cat $S_PATH | sed '/^#!.*/q' | tail -n 1 | sed 's/^#![ ]*//')
  local INTERPRETER="${SHBANG_LINE%% *}"
  ADD_PATHS="$INTERPRETER"
  if [ "$(basename $INTERPRETER)" == "env" ]; then
    ADD_PATHS="$INTERPRETER"
    INTERPRETER="${SHBANG_LINE#* }" # This is in case there are parameters for the interpreter e.g. #!/usr/bin/env bash -c
    INTERPRETER="${INTERPRETER%% *}"
    local W_INTERPRETER="$(which "$INTERPRETER")"
    if [ "$W_INTERPRETER" != "" ]; then
      INTERPRETER="$W_INTERPRETER"
    fi
    ADD_PATHS="${ADD_PATHS}
$INTERPRETER
"
  fi

  case "$(basename "$INTERPRETER")" in
    perl) ADD_PATHS="${ADD_PATHS}
$(perl -e "print qq(@INC)" | tr ' ' '\n' | grep -v -e '^/home' -e '^\.')";;
    python) ADD_PATHS="${ADD_PATHS}
$(python -c 'import sys;print "\n".join(sys.path)' | grep -v -e '^/home' -e '^\.')";;
    bash) ;;
    python) ;;
    *)    p_warning "interpreter $INTERPRETER not recognised"
          return 0;;
  esac

  if [ "$ADD_PATHS" != "" ]; then
    p_debug "found that $S_PATH needs $ADD_PATHS"
    local P
    while read P; do
      [ "$P" != "" ] && add_command "$P"
    done <<< "$ADD_PATHS"
  fi
  return 0
}

function PLUGIN_funcs() {
  # Gets the list of plugins available for the app (those functions named PLUGIN_xxx_<plugin name>)
  echo "$(typeset -F | grep PLUGIN_ | awk '{print $3}' | grep -v 'PLUGIN_funcs')"
}

function plugin_list() {
  local P
  while read P; do
    echo -n "${P##*_},"
  done <<< "$(PLUGIN_funcs)"
  echo
}