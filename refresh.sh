#!/usr/bin/env bash

# This makes use of the standard variables used by the installer
eval "$(curl -fsSL https://raw.githubusercontent.com/MISP/MISP/2.4/docs/generic/globalVariables.md | grep -v \`\`\`)"
MISPvars > /dev/null 2>&1

if [ ! -d ${PATH_TO_MISP} ]; then
  echo "This script expects MISP to be installed in ${PATH_TO_MISP}, it does not exist, bye."
  exit 127
fi

ask_o () {

  ANSWER=""

  if [ -z "${1}" ]; then
    echo "This function needs at least 1 parameter."
    exit 1
  fi

  [ -z "$2" ] && OPT1="y" || OPT1=$2
  [ -z "$3" ] && OPT2="n" || OPT2=$3

  while true; do
    case $ANSWER in ${OPT1} | ${OPT2}) break ;; esac
    echo -n "${1} (${OPT1}/${OPT2}) "
    read ANSWER
    ANSWER=$(echo $ANSWER |  tr '[:upper:]' '[:lower:]')
  done

}

ask_o "Do you want to wipe this MISP instance?"

if [[ "${ANSWER}" == "y" ]]; then
  echo "PATH_TO_MISP=${PATH_TO_MISP}" |$SUDO_WWW tee ${PATH_TO_MISP}/tools/misp-wipe/misp-wipe.conf

ask_o "Do you want to reset the Base Organisation?"

ask_o "Do you want to regenerate the self-signed SSL certificate?"

ask_o "Do you want to regenerate the SSH server keys?"
