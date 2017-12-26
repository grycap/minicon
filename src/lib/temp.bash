function tempfile {
  local FOLDER="$1"
  if [ "$FOLDER" == "" ]; then
    FOLDER=/tmp
  fi
  if [ ! -d "$FOLDER" ]; then
    finalize 1 "folder $FOLDER does not exist"
  fi
  RES=$FOLDER/ftemp_${RANDOM}_$(date +%s)
  touch $RES
  while [ $? -ne 0 ]; do
    RES=$FOLDER/ftemp_${RANDOM}_$(date +%s)
    touch $RES
  done
  echo $RES
}

function tempdir() {
  # Creates a unique temporary folder
  local FOLDER="$1"
  if [ "$FOLDER" == "" ]; then
    FOLDER=/tmp
  fi
  if [ ! -d "$FOLDER" ]; then
    finalize 1 "folder $FOLDER does not exist"
  fi
  RES=$FOLDER/ftemp_${RANDOM}_$(date +%s)
  mkdir -p $RES 2> /dev/null
  while [ $? -ne 0 ]; do
    RES=$FOLDER/ftemp_${RANDOM}_$(date +%s)
    mkdir -p $RES 2> /dev/null
  done
  echo $RES
}