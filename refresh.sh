#!/usr/bin/env bash

ask_o () {

  if [ -z ${1} ]; then
    echo "This function needs at least 1 parameter."
    exit 1
  fi

  [ -z $2 ] && OPT1="y" || OPT1=$2
  [ -z $3 ] && OPT2="n" || OPT2=$3

  while true; do
    case $ANSWER in ${OPT1} | ${OPT2}) break ;; esac
    echo -n "${1} (${OPT1}/${OPT2}) "
    read ANSWER
    ANSWER=$(echo $ANSWER |  tr '[:upper:]' '[:lower:]')
  done

}
