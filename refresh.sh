#!/usr/bin/env bash

# Variables section begin

PATH_TO_MISP="/var/www/MISP"
if [ ! -d ${PATH_TO_MISP} ]; then
  echo "This script expects MISP to be installed in ${PATH_TO_MISP}, it does not exist, bye."
  exit 126
fi

# This makes use of the standard variables used by the installer
echo "Fetching MISP globalVariables"
eval "$(cat /var/www/MISP/docs/generic/globalVariables.md | grep -v \`\`\`)"
MISPvars > /dev/null 2>&1

if [ $(jq --version > /dev/null 2>&1; echo $?) == 127 ]; then
  echo "jq not found, please install: sudo apt install jq"
  exit 127
fi

if [ "$(cat $PATH_TO_MISP/VERSION.json |jq -r .hotfix)" -le "108" ]; then
  echo "You need at least MISP v2.4.109 for this to work properly"
  exit 1
fi


# Include the lovely supportFunctions that are the base of MISP installer
echo "Fetching MISP supportFunctions"
eval "$(cat $PATH_TO_MISP/docs/generic/supportFunctions.md | grep -v \`\`\`)"

# Combine SUDO_WWW and CAKE for ease of use
CAKE="$SUDO_WWW$CAKE"

# Variables section end


# Functions section begin

rc () {
  echo -e "$1 Press enter to continue."
  space
  space
  read
  clear
}

misp-wipe () {
  echo -e "/\!\\ THE FOLLOWING WILL WIPE YOUR ENTIRE MISP INSTANCE\!\nThe default id=1 is NOT wiped.\nPRESS ENTER TO CONTINUE..."
  read
  echo "PATH_TO_MISP=${PATH_TO_MISP}" |$SUDO_WWW tee ${PATH_TO_MISP}/tools/misp-wipe/misp-wipe.conf
  cd ${PATH_TO_MISP}/tools/misp-wipe
  sudo ./misp-wipe.sh
  rc "Wipe done."
}

reset-org () {
  CAKE_ORG=$($CAKE Admin getSetting "MISP.org" |tail -n +7 |jq -r '[.description,.value] |@tsv')
  DESCRIPTION=$(echo "$CAKE_ORG"| cut -f 1)
  VALUE=$(echo "$CAKE_ORG"| cut -f 2)
  echo -e "The value of MISP.org is: $VALUE\n"
  echo "Here is the description of the setting: $DESCRIPTION"
  echo -n "Please enter the new Org name: "
  read NEW_ORG
  $CAKE Admin setSetting "MISP.org" "$NEW_ORG"
  rc "New Base Organisation name: $NEW_ORG"

  ask_o "Do you want to reset the Organisation UUID?"
  if [[ "$ANSWER" == "y" ]]; then
    CAKE_ORG_UUID=$($CAKE Admin getSetting "MISP.uuid" |tail -n +7 |jq -r '[.description,.value] |@tsv')
    DESCRIPTION=$(echo "$CAKE_ORG_UUID"| cut -f 1)
    VALUE=$(echo "$CAKE_ORG_UUID"| cut -f 2)
    echo -e "The value of MISP.uuid is: $VALUE\n"
    echo "Here is the description of the setting: $DESCRIPTION"
    space
    echo -e "/\!\\ Please do understand what impact this might have on synchronisations etc.\nOn new installs this is OK.\nPress enter to continue with change."
    read
    NEW_UUID=$(uuidgen)
    $CAKE Admin setSetting "MISP.uuid" "$NEW_UUID"
    rc "The new UUID is: $NEW_UUID"
  fi

  ask_o "Do you want to reset the Organisation E-Mail?"
  if [[ "$ANSWER" == "y" ]]; then
    CAKE_ORG_EMAIL=$($CAKE Admin getSetting "MISP.email" |tail -n +7 |jq -r '[.description,.value] |@tsv')
    DESCRIPTION=$(echo "$CAKE_ORG_EMAIL"| cut -f 1)
    VALUE=$(echo "$CAKE_ORG_EMAIL"| cut -f 2)
    echo -e "The value of MISP.email is: $VALUE\n"
    echo "Here is the description of the setting: $DESCRIPTION"
    space
    echo -n "Please enter the new Org E-Mail Address: "
    read NEW_MAIL
    $CAKE Admin setSetting "MISP.email" "$NEW_MAIL"
    rc "New Base Organisation name: $NEW_MAIL"
  fi

  rc "Org reset done."
}

reset-baseurl () {
  CAKE_BASEURL=$($CAKE Admin getSetting "MISP.baseurl" |tail -n +7 |jq -r '[.description,.value] |@tsv')
  DESCRIPTION=$(echo "$CAKE_BASEURL"| cut -f 1)
  VALUE=$(echo "$CAKE_BASEURL"| cut -f 2)
  echo -e "The value of MISP.baseurl is: $VALUE\n"
  echo "Here is the description of the setting: $DESCRIPTION"
  space
  echo -n "Please enter the new BaseURL: "
  read NEW_BASEURL
  $CAKE Admin setSetting "MISP.baseurl" "$NEW_BASEURL"
  rc "BaseURL reset done."
}

reset-texts () {
  CAKE_FOOTER_LEFT=$($CAKE Admin getSetting "MISP.footermidleft" |tail -n +7 |jq -r '[.description,.value] |@tsv')
  DESCRIPTION=$(echo "$CAKE_FOOTER_LEFT"| cut -f 1)
  VALUE=$(echo "$CAKE_FOOTER_LEFT"| cut -f 2)
  echo -e "The value of MISP.footermidleft is: $VALUE\n"
  echo "Here is the description of the setting: $DESCRIPTION"
  space
  CAKE_FOOTER_RIGHT=$($CAKE Admin getSetting "MISP.footermidright" |tail -n +7 |jq -r '[.description,.value] |@tsv')
  DESCRIPTION=$(echo "$CAKE_FOOTER_RIGHT"| cut -f 1)
  VALUE=$(echo "$CAKE_FOOTER_RIGHT"| cut -f 2)
  echo -e "The value of MISP.footermidright is: $VALUE\n"
  echo "Here is the description of the setting: $DESCRIPTION"
  space
  CAKE_TEXT_TOP=$($CAKE Admin getSetting "MISP.welcome_text_top" |tail -n +7 |jq -r '[.description,.value] |@tsv')
  DESCRIPTION=$(echo "$CAKE_TEXT_TOP"| cut -f 1)
  VALUE=$(echo "$CAKE_TEXT_TOP"| cut -f 2)
  echo -e "The value of MISP.welcome_text_top is: $VALUE\n"
  echo "Here is the description of the setting: $DESCRIPTION"
  space
  CAKE_TEXT_BOTTOM=$($CAKE Admin getSetting "MISP.welcome_text_bottom" |tail -n +7 |jq -r '[.description,.value] |@tsv')
  DESCRIPTION=$(echo "$CAKE_TEXT_BOTTOM"| cut -f 1)
  VALUE=$(echo "$CAKE_TEXT_BOTTOM"| cut -f 2)
  echo -e "The value of MISP.welcome_text_bottom is: $VALUE\n"
  echo "Here is the description of the setting: $DESCRIPTION"
  space
  space
  for setting in $(echo "footermidleft footermidright welcome_text_top welcome_text_bottom"); do
    echo -n "Please enter text for '${setting}' (Enter for blank): "
    read VALUE
    if [ -z $VALUE ]; then
      $CAKE Admin setSetting "MISP.${setting}" false
    else
      $CAKE Admin setSetting "MISP.${setting}" "$VALUE"
    fi
  done

  rc "All done."
}

regen-cert () {
  CAKE_ORG=$($CAKE Admin getSetting "MISP.org" |tail -n +7 |jq -r '[.description,.value] |@tsv')
  VALUE=$(echo "$CAKE_ORG"| cut -f 2)
  OPENSSL_O=$VALUE

  ask_o "Using $FQDN as common name, do you want to change it?"
  if [[ "$ANSWER" == "y" ]]; then
    echo -n "Please enter the certificate common name: "
    read OPENSSL_CN
  fi

  ask_o "Using $OPENSSL_EMAILADDRESS as contact email for the certificate, do you want to change it?"
  if [[ "$ANSWER" == "y" ]]; then
    echo -n "Please enter the certificate contact email: "
    read OPENSSL_EMAILADDRESS
  fi

  ask_o "Using $OPENSSL_O as Organisation, do you want to change it?"
  if [[ "$ANSWER" == "y" ]]; then
    echo -n "Please enter the certificate Organisation: "
    read OPENSSL_O
  fi

  ask_o "Using $OPENSSL_C as ISO Country Code, do you want to change it?"
  if [[ "$ANSWER" == "y" ]]; then
    echo -n "Please enter the ISO Country Code for the certificate: "
    read OPENSSL_O
  fi

  sudo openssl req -newkey rsa:4096 -days 365 -nodes -x509 \
  -subj "/C=${OPENSSL_C}/O=${OPENSSL_O}/CN=${OPENSSL_CN}/emailAddress=${OPENSSL_EMAILADDRESS}" \
  -keyout /etc/ssl/private/misp.local.key -out /etc/ssl/private/misp.local.crt
  sudo systemctl restart apache2

  rc "New certificate created.\nPlease consider using a Signed certificate like https://letsencrypt.org/"
}

regen-ssh () {
  echo "Removing: /etc/ssh/ssh_host_* (forcefully)"
  sudo rm -vf /etc/ssh/ssh_host_*
  echo '#!/bin/bash
/usr/sbin/dpkg-reconfigure openssh-server
rm $0' |sudo tee /etc/init.d/firstBoot
  sudo chmod +x /etc/init.d/firstBoot
  rc "Please reboot to regenerate SSH keys."
}

regen-gpg () {
  echo "Removing '$PATH_TO_MISP/.gnupg' (forcefully)"
  sudo rm -rf $PATH_TO_MISP/.gnupg

  echo -n "Please enter a 'Real Name' for your GPG Key. (misppriv@circl.lu uses: MISP CIRCL for Private Sector): "
  read GPG_REAL_NAME
  echo -n "Enter an E-Mail address for the Key: "
  read GPG_EMAIL_ADDRESS
  ask_o "The Autogenerated Password for this key is: '$GPG_PASSPHRASE'. Do you want to change it?"
  if [[ "$ANSWER" == "y" ]]; then
    echo -n "Please enter a Passphrase for the GPG Key: "
    read GPG_PASSPHRASE
  fi

  echo "%echo Generating a default key
      Key-Type: default
      Key-Length: $GPG_KEY_LENGTH
      Subkey-Type: default
      Name-Real: $GPG_REAL_NAME
      Name-Comment: $GPG_COMMENT
      Name-Email: $GPG_EMAIL_ADDRESS
      Expire-Date: 0
      Passphrase: $GPG_PASSPHRASE
      # Do a commit here, so that we can later print "done"
      %commit
    %echo done" > /tmp/gen-key-script

  $SUDO_WWW gpg --homedir $PATH_TO_MISP/.gnupg --batch --gen-key /tmp/gen-key-script

  # Export the public key to the webroot
  $SUDO_WWW sh -c "gpg --homedir $PATH_TO_MISP/.gnupg --export --armor $GPG_EMAIL_ADDRESS" | $SUDO_WWW tee $PATH_TO_MISP/app/webroot/gpg.gpg.asc
  rm -f /tmp/gen-key-script
  $CAKE Admin setSetting "GnuPG.email" "$GPG_EMAIL_ADDRESS"
  $CAKE Admin setSetting "GnuPG.password" "$GPG_PASSPHRASE"

  rc "New PGP key created."
}

# Functions section begin


# Main section begin
# Use misp-wipe.sh to clean everything
ask_o "Do you want to wipe this MISP instance?"
[[ "${ANSWER}" == "y" ]] && misp-wipe

ask_o "Do you want to reset the BaseURL?"
[[ "${ANSWER}" == "y" ]] && reset-baseurl

ask_o "Do you want to reset the Base Organisation?"
[[ "${ANSWER}" == "y" ]] && reset-org

ask_o "Do you want to reset the welcome texts and footers?"
[[ "${ANSWER}" == "y" ]] && reset-texts

ask_o "Do you want to regenerate the self-signed SSL certificate?"
[[ "${ANSWER}" == "y" ]] && regen-cert

ask_o "Do you want to regenerate the SSH server keys?"
[[ "${ANSWER}" == "y" ]] && regen-ssh

ask_o "Do you want to regenerate the MISP GPG keys?"
[[ "${ANSWER}" == "y" ]] && regen-gpg

#ask_o "Do you want to update MISP?
#[[ "${ANSWER}" == "y" ]] && update-misp

# Main section end
