#!/usr/bin/env bash

# This makes use of the standard variables used by the installer
eval "$(curl -fsSL https://raw.githubusercontent.com/MISP/MISP/2.4/docs/generic/globalVariables.md | grep -v \`\`\`)"
MISPvars > /dev/null 2>&1

CAKE="$SUDO_WWW$CAKE"

CAKE_BASEURL=$($CAKE Admin getSetting "MISP.baseurl" |tail -n +7 |jq -r '[.description,.value] |@tsv')
DESCRIPTION=$(echo "$CAKE_BASEURL"| cut -f 1)
VALUE=$(echo "$CAKE_BASEURL"| cut -f 2)
echo "The value of MISP.baseurl is: $VALUE"
echo
echo "Here is the description of the setting: $DESCRIPTION"
read
CAKE_ORG_UUID=$($CAKE Admin getSetting "MISP.uuid" |tail -n +7 |jq -r '[.description,.value] |@tsv')
DESCRIPTION=$(echo "$CAKE_ORG_UUID"| cut -f 1)
VALUE=$(echo "$CAKE_ORG_UUID"| cut -f 2)
echo "The value of MISP.uuid is: $VALUE"
echo
echo "Here is the description of the setting: $DESCRIPTION"
read
CAKE_ORG_EMAIL=$($CAKE Admin getSetting "MISP.email" |tail -n +7 |jq -r '[.description,.value] |@tsv')
DESCRIPTION=$(echo "$CAKE_ORG_EMAIL"| cut -f 1)
VALUE=$(echo "$CAKE_ORG_EMAIL"| cut -f 2)
echo "The value of MISP.email is: $VALUE"
echo
echo "Here is the description of the setting: $DESCRIPTION"
read
CAKE_ORG=$($CAKE Admin getSetting "MISP.org" |tail -n +7 |jq -r '[.description,.value] |@tsv')
DESCRIPTION=$(echo "$CAKE_ORG"| cut -f 1)
VALUE=$(echo "$CAKE_ORG"| cut -f 2)
echo "The value of MISP.org is: $VALUE"
echo
echo "Here is the description of the setting: $DESCRIPTION"
read
CAKE_FOOTER_LEFT=$($CAKE Admin getSetting "MISP.footermidleft" |tail -n +7 |jq -r '[.description,.value] |@tsv')
DESCRIPTION=$(echo "$CAKE_FOOTER_LEFT"| cut -f 1)
VALUE=$(echo "$CAKE_FOOTER_LEFT"| cut -f 2)
echo "The value of MISP.footermidleft is: $VALUE"
echo
echo "Here is the description of the setting: $DESCRIPTION"
read
CAKE_FOOTER_RIGHT=$($CAKE Admin getSetting "MISP.footermidright" |tail -n +7 |jq -r '[.description,.value] |@tsv')
DESCRIPTION=$(echo "$CAKE_FOOTER_RIGHT"| cut -f 1)
VALUE=$(echo "$CAKE_FOOTER_RIGHT"| cut -f 2)
echo "The value of MISP.footermidright is: $VALUE"
echo
echo "Here is the description of the setting: $DESCRIPTION"
read
CAKE_TEXT_TOP=$($CAKE Admin getSetting "MISP.welcome_text_top" |tail -n +7 |jq -r '[.description,.value] |@tsv')
DESCRIPTION=$(echo "$CAKE_TEXT_TOP"| cut -f 1)
VALUE=$(echo "$CAKE_TEXT_TOP"| cut -f 2)
echo "The value of MISP.welcome_text_top is: $VALUE"
echo
echo "Here is the description of the setting: $DESCRIPTION"
read
CAKE_TEXT_BOTTOM=$($CAKE Admin getSetting "MISP.welcome_text_bottom" |tail -n +7 |jq -r '[.description,.value] |@tsv')
DESCRIPTION=$(echo "$CAKE_TEXT_BOTTOM"| cut -f 1)
VALUE=$(echo "$CAKE_TEXT_BOTTOM"| cut -f 2)
echo "The value of MISP.welcome_text_bottom is: $VALUE"
echo
echo "Here is the description of the setting: $DESCRIPTION"

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
  cd ${PATH_TO_MISP}/tools/misp-wipe
  sudo ./misp-wipe.sh
fi

ask_o "Do you want to reset the Base Organisation?"

ask_o "Do you want to regenerate the self-signed SSL certificate?"

ask_o "Do you want to regenerate the SSH server keys?"

#ask_o "Do you want to update MISP?
