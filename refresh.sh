#!/usr/bin/env bash

# Variables section begin
PATH_TO_MISP="${PATH_TO_MISP:-/var/www/MISP}"
if [ ! -d ${PATH_TO_MISP} ]; then
  echo -e "This script expects ${LBLUE}MISP${NC} to be installed in ${YELLOW}${PATH_TO_MISP}${NC}, it does not exist, bye."
  echo "You can override this by setting the environment variable: PATH_TO_MISP"
  exit 126
fi

# This makes use of the standard variables used by the installer
echo -e "Fetching ${LBLUE}MISP${NC} globalVariables"
eval "$(curl -fsSL https://raw.githubusercontent.com/MISP/MISP/2.4/docs/generic/globalVariables.md | awk '/^# <snippet-begin/,0' | grep -v \`\`\`)" || eval "$(${SUDO_WWW} cat ${PATH_TO_MISP}/docs/generic/globalVariables.md | awk '/^# <snippet-begin/,0' | grep -v \`\`\`)"
MISPvars > /dev/null 2>&1

# Simple debug function with message (recycled from INSTALL.tpl.sh)

# Make sure no alias exists
[[ $(type -t debug) == "alias" ]] && unalias debug
debug () {
  if [[ ! -z ${UNATTENDED} ]]; then
    echo "Unattende mode active"
    :
    # return
  fi
  echo -e "${RED}Next step:${NC} ${GREEN}$1${NC}" > /dev/tty
  if [ ! -z ${DEBUG} ]; then
    NO_PROGRESS=1
    echo -e "${RED}Debug Mode${NC}, press ${LBLUE}enter${NC} to continue..." > /dev/tty
    exec 3>&1
    read
  else
    # [Set up conditional redirection](https://stackoverflow.com/questions/8756535/conditional-redirection-in-bash)
    #exec 3>&1 &>/dev/null
    :
  fi
}

if [ $(jq --version > /dev/null 2>&1; echo $?) == 127 ]; then
  echo -e "jq not found, please install:\nsudo apt install jq"
  exit 127
fi

if [ $(dialog > /dev/null 2>&1; echo $?) == 0 ]; then
  DIALOG=${DIALOG:-1}
fi

# The setOpt/checkOpt function lives in generic/supportFunctions.md
setOpt $@
# Check for non-interactivity and be non-verbose
checkOpt unattended && echo "${LBLUE}MISP${NC} Refresh ${GREEN}non-interactive${NC} selected"

if [ "$(${SUDO_WWW} cat ${PATH_TO_MISP}/VERSION.json |jq -r .hotfix)" -le "108" ]; then
  echo "You need at least ${LBLUE}MISP${NC} v2.4.109 for this to work properly"
  exit 1
fi

# Include the lovely supportFunctions that are the base of MISP installer
echo "Fetching ${LBLUE}MISP${NC} supportFunctions"
eval "$(curl -fsSL https://raw.githubusercontent.com/MISP/MISP/2.4/docs/generic/supportFunctions.md | awk '/^# <snippet-begin/,0' | grep -v \`\`\`)" || eval "$(${SUDO_WWW} cat ${PATH_TO_MISP}/docs/generic/supportFunctions.md | | awk '/^# <snippet-begin/,0' | grep -v \`\`\`)"

# Combine SUDO_WWW and CAKE for ease of use
CAKE="${SUDO_WWW}${CAKE}"

# JSON Variables

USER_JSON='{"User": {"email": "#EMAIL_ADDRESS#"}}'
ORGA_JSON='{"Organisation": {"name": "#ORGA_NAME#", "uuid": "#ORGA_UUID#"}}'

DBUSER_MISP=$(${SUDO_WWW} grep -o -P "(?<='login' => ').*(?=')" ${PATH_TO_MISP}/app/Config/database.php)
[[ "$?" != "0" ]] && (echo "Cannot set DBUSER_MISP please check permissions or paths." ; exit -1)
DBPASSWORD_MISP=$(${SUDO_WWW} grep -o -P "(?<='password' => ').*(?=')" ${PATH_TO_MISP}/app/Config/database.php)
[[ "$?" != "0" ]] && (echo "Cannot set DBPASSWORD_MISP please check permissions or paths." ; exit -1)
DBNAME=$(${SUDO_WWW} grep -o -P "(?<='database' => ').*(?=')" ${PATH_TO_MISP}/app/Config/database.php)
[[ "$?" != "0" ]] && (echo "Cannot set DBNAME please check permissions or paths." ; exit -1)

# TODO: Make use of Host/Port
DB_Port=$(${SUDO_WWW} grep -m1 -o -P "(?<='port' => ).*(?=,)" ${PATH_TO_MISP}/app/Config/database.php) ; [[ -z ${MISPDBPort} ]] && MISPDBPort="3306"
MISPDBHost=$(${SUDO_WWW} grep -o -P "(?<='host' => ').*(?=')" ${PATH_TO_MISP}/app/Config/database.php) ; [[ -z ${MISPDBHost} ]] && MISPDBHost="localhost"
AUTH_KEY=$(mysql --disable-column-names -B  -u ${DBUSER_MISP} -p"${DBPASSWORD_MISP}" ${DBNAME} -e 'SELECT authkey FROM users WHERE role_id=1 LIMIT 1')

# Variables section end


# Functions section begin

colors () {
  # Some colors for easier debug and better UX (not colorblind compatible, PR welcome)
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  LBLUE='\033[1;34m'
  YELLOW='\033[0;33m'
  HIDDEN='\e[8m'
  NC='\033[0m'
}

rc () {
  echo -e "$1 ${GREEN}->${NC} ${LBLUE}Press enter to continue.${NC}"
  space
  space
  read
  clear
}

misp-wipe () {
  echo -e "${RED}/!\\ ${NC}THE FOLLOWING WILL ${RED}WIPE YOUR ENTIRE${NC} ${LBLUE}MISP${NC} ${RED}INSTANCE${NC}!\nThe default id=1 is NOT wiped. NOR is '${YELLOW}config.php${NC}' wiped.\n${LBLUE}PRESS ENTER TO CONTINUE...${NC}"
  read
  echo "PATH_TO_MISP=${PATH_TO_MISP}" |${SUDO_WWW} tee ${PATH_TO_MISP}/tools/misp-wipe/misp-wipe.conf
  cd ${PATH_TO_MISP}/tools/misp-wipe
  sudo ./misp-wipe.sh
  space
  rc "${GREEN}Wipe done.${NC}"
}

genKeys () {
  echo "misp_url = 'https://localhost'
misp_key = '${AUTH_KEY}'
misp_verifycert = False
" |tee /tmp/keys.py 1> /dev/null
}

# TODO: Finish implementation.
resetAdmin () {
  echo -n "Please enter new password for the Admin Mail ${ADMIN_EMAIL} : "
  read PASSWORD
  ${CAKE} Password ${ADMIN_EMAIL} ${PASSWORD}
}

genPyMISP () {
  echo 'from keys import *
from pymisp import ExpandedPyMISP, PyMISP
import json

misp = ExpandedPyMISP(misp_url, misp_key, misp_verifycert)

print(json.dumps(misp.edit_organisation(1)))' |tee /tmp/getOrgInfo.py 1> /dev/null

  echo 'from keys import *
from pymisp import ExpandedPyMISP, PyMISP
import json

misp = ExpandedPyMISP(misp_url, misp_key, misp_verifycert)

print(json.dumps(misp.edit_user(1)))' |tee /tmp/getUserInfo.py 1> /dev/null
  cp ${PATH_TO_MISP}/PyMISP/examples/edit_user_json.py /tmp
  # Next line needs merging up-stream
  if [[ ! -e ${PATH_TO_MISP}/PyMISP/examples/edit_organisation_json.py ]]; then
    wget --no-cache -O /tmp/edit_organisation_json.py https://raw.githubusercontent.com/MISP/PyMISP/main/examples/edit_organisation_json.py
  else
    cp ${PATH_TO_MISP}/PyMISP/examples/edit_organisation_json.py /tmp
  fi
}

getOrgInfo () {
  [[ $(chkVenv) != "0" ]] && return
  [[ ! -e /tmp/keys.py ]] && genKeys
  [[ ! -e /tmp/getOrgInfo.py ]] && genPyMISP
  orgInfo=$(${PATH_TO_MISP}/venv/bin/python /tmp/getOrgInfo.py 2>/dev/null)
  [[ "$1" == "v" ]] && echo ${orgInfo}
}

getUserInfo () {
  [[ $(chkVenv) != "0" ]] && return
  [[ ! -e /tmp/keys.py ]] && genKeys
  [[ ! -e /tmp/getUserInfo.py ]] && genPyMISP
  userInfo=$(${PATH_TO_MISP}/venv/bin/python /tmp/getUserInfo.py 2>/dev/null)
  [[ "$1" == "v" ]] && echo ${userInfo}
}

chkVenv () {
  echo $(${PATH_TO_MISP}/venv/bin/python -V >/dev/null 2>&1; echo $?)
}

purge-log () {
  folder_dest=/var/log/misp

  [[ ! -d ${folder_dest} ]] && (sudo mkdir ${folder_dest} ; sudo chown $(id -u):$(id -g) ${folder_dest})

  # get today minus 6 month
  dateForCleaning=$(date +'%Y-%m-%d' --date='-6 month')
  #now=$(date +'%Y-%m-%d %')

  # purge logs
  QUERY1='SELECT count(*) from logs where date(created) <"'${dateForCleaning}'";'
  QUERY2='DELETE from logs WHERE date(created) < "'${dateForCleaning}'";'
  #echo $query

  tmp=$(mysql -u ${DBUSER_MISP} -p"${DBPASSWORD_MISP}" ${DBNAME} -N -e "${QUERY1}")
  mysql -u ${DBUSER_MISP} -p"${DBPASSWORD_MISP}" ${DBNAME} -N -e "${QUERY2}"
  if [[ $? != 0 ]]; then
    echo "Error in log purge"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - ${tmp} lines in logs table before ${dateForCleaning} - ERROR during delete" >> ${folder_dest}/cleaning_6month.log
  else
    echo "$(date +'%Y-%m-%d %H:%M:%S') - ${tmp} lines in logs table before ${dateForCleaning} - No Error during deletion" >> ${folder_dest}/cleaning_6month.log
  fi
}

reset-org () {
  CAKE_ORG=$(${CAKE} Admin getSetting "MISP.org" |tail -n +7 |jq -r '[.description,.value] |@tsv')
  DESCRIPTION=$(echo "${CAKE_ORG}"| cut -f 1)
  VALUE=$(echo "${CAKE_ORG}"| cut -f 2)
  echo -e "The value of MISP.org is: ${YELLOW}${VALUE}${NC}\n"
  echo -e "Here is the description of the setting: ${DESCRIPTION}"
  echo -n "Please enter the new Orga short-tag (misppriv uses 'CIRCL'): "
  read NEW_ORG
  ${CAKE} Admin setSetting "MISP.org" "${NEW_ORG}"
  rc "New Base Organisation short-tag: ${YELLOW}${NEW_ORG}${NC}"

  ask_o "Do you want to reset the Organisation UUID?"
  if [[ "${ANSWER}" == "y" ]]; then
    CAKE_ORG_UUID=$(${CAKE} Admin getSetting "MISP.uuid" |tail -n +7 |jq -r '[.description,.value] |@tsv')
    DESCRIPTION=$(echo "${CAKE_ORG_UUID}"| cut -f 1)
    VALUE=$(echo "${CAKE_ORG_UUID}"| cut -f 2)
    echo -e "The value of MISP.uuid is: ${YELLOW}${VALUE}${NC}\n"
    echo "Here is the description of the setting: ${DESCRIPTION}"
    space
    echo -e "${RED}/!\\ ${NC}Please do understand what impact this might have on synchronisations etc.\nOn new installs this is OK.\n${LBLUE}Press enter to continue with change.${NC}"
    read
    # Set the new UUID into the system settings via Cake
    NEW_UUID=$(uuidgen)
    ${CAKE} Admin setSetting "MISP.uuid" "${NEW_UUID}"
    # Set the new UUID in the existing base organisation via PyMISP
    getOrgInfo
    ORGA_NAME=$(echo ${orgInfo} |jq -r .Organisation.name)
    ORGA_UUID=${NEW_UUID}
    if [[ $(chkVenv) == "0" ]]; then
      echo ${ORGA_JSON} | sed "s/#ORGA_UUID#/${ORGA_UUID}/" | sed "s/#ORGA_NAME#/${ORGA_NAME}/" > /tmp/orga.json
      ${PATH_TO_MISP}/venv/bin/python /tmp/edit_organisation_json.py -i 1 -f /tmp/orga.json 2> /dev/null
    fi
    
    rc "The new UUID is: ${YELLOW}${NEW_UUID}${NC}"
  fi

  getOrgInfo
  ORGA_NAME=$(echo ${orgInfo} |jq -r .Organisation.name)
  ORGA_UUID=$(echo ${orgInfo} |jq -r .Organisation.uuid)
  if [[ $(chkVenv) == "0" ]]; then
    ask_o "Do you want to reset the Organisation name, currently: ${YELLOW}${ORGA_NAME}${NC} ?"
    if [[ "${ANSWER}" == "y" ]]; then
      echo -n "Please enter the new Orga name, can have spaces: "
      read ORGA_NAME
      echo ${ORGA_JSON} | sed "s/#ORGA_UUID#/${ORGA_UUID}/" | sed "s/#ORGA_NAME#/${ORGA_NAME}/" > /tmp/orga.json
      ${PATH_TO_MISP}/venv/bin/python /tmp/edit_organisation_json.py -i 1 -f /tmp/orga.json 2> /dev/null
    fi
    
    rc "The new Name is: ${YELLOW}${ORGA_NAME}${NC}"
  fi

  ask_o "Do you want to reset the notification E-Mail?"
  if [[ "${ANSWER}" == "y" ]]; then
    CAKE_NOTIFICATION_EMAIL=$(${CAKE} Admin getSetting "MISP.email" |tail -n +7 |jq -r '[.description,.value] |@tsv')
    DESCRIPTION=$(echo "${CAKE_NOTIFICATION_EMAIL}"| cut -f 1)
    VALUE=$(echo "${CAKE_NOTIFICATION_EMAIL}"| cut -f 2)
    echo -e "The value of MISP.email is: ${YELLOW}${VALUE}${NC}\n"
    echo "Here is the description of the setting: ${DESCRIPTION}"
    space
    echo -n "Please enter the new notification E-Mail Address: "
    read NEW_MAIL
    # Set the new notification E-Mail into the system settings via Cake
    ${CAKE} Admin setSetting "MISP.email" "${NEW_MAIL}"
    rc "New notification E-Mail address is: ${YELLOW}${NEW_MAIL}${NC}"
  fi

  ask_o "Do you want to reset the Base Organisation admin E-Mail?"
  if [[ "${ANSWER}" == "y" ]]; then
    getUserInfo v |jq
    rc "Above you see the current configuration."
    space
    echo -n "Please enter the new E-Mail Address: "
    read NEW_MAIL
    # Set the new UUID in the existing base organisation via PyMISP
    getUserInfo
    USER_MAIL=$(echo ${userInfo} |jq -r .User.email)
    if [[ $(chkVenv) == "0" ]]; then
      echo ${USER_JSON} | sed "s/#EMAIL_ADDRESS#/${NEW_MAIL}/" > /tmp/user.json
      ${PATH_TO_MISP}/venv/bin/python /tmp/edit_user_json.py -i 1 -f /tmp/user.json 2> /dev/null
    fi
    
    rc "The new E-Mail address is: ${YELLOW}${NEW_MAIL}${NC}"

  fi

  rc "Org reset done."
}

reset-baseurl () {
  CAKE_BASEURL=$(${CAKE} Admin getSetting "MISP.baseurl" |tail -n +7 |jq -r '[.description,.value] |@tsv')
  DESCRIPTION=$(echo "${CAKE_BASEURL}"| cut -f 1)
  VALUE=$(echo "${CAKE_BASEURL}"| cut -f 2)
  echo -e "The value of ${LBLUE}MISP.baseurl${NC} is: ${YELLOW}${VALUE}${NC}\n"
  echo "Here is the description of the setting: ${DESCRIPTION}"
  space
  echo -n "Please enter the new BaseURL: "
  read NEW_BASEURL
  ${CAKE} Admin setSetting "MISP.baseurl" "${NEW_BASEURL}"
  rc "BaseURL reset done."
}

reset-texts () {
  CAKE_FOOTER_LEFT=$(${CAKE} Admin getSetting "MISP.footermidleft" |tail -n +7 |jq -r '[.description,.value] |@tsv')
  DESCRIPTION=$(echo "${CAKE_FOOTER_LEFT}"| cut -f 1)
  VALUE=$(echo "${CAKE_FOOTER_LEFT}"| cut -f 2)
  echo -e "The value of ${LBLUE}MISP.footermidleft${NC} is: ${YELLOW}${VALUE}${NC}\n"
  echo "Here is the description of the setting: ${DESCRIPTION}"
  space
  CAKE_FOOTER_RIGHT=$(${CAKE} Admin getSetting "MISP.footermidright" |tail -n +7 |jq -r '[.description,.value] |@tsv')
  DESCRIPTION=$(echo "${CAKE_FOOTER_RIGHT}"| cut -f 1)
  VALUE=$(echo "${CAKE_FOOTER_RIGHT}"| cut -f 2)
  echo -e "The value of ${LBLUE}MISP.footermidright${NC} is: ${YELLOW}${VALUE}${NC}\n"
  echo "Here is the description of the setting: ${DESCRIPTION}"
  space
  CAKE_TEXT_TOP=$(${CAKE} Admin getSetting "MISP.welcome_text_top" |tail -n +7 |jq -r '[.description,.value] |@tsv')
  DESCRIPTION=$(echo "${CAKE_TEXT_TOP}"| cut -f 1)
  VALUE=$(echo "${CAKE_TEXT_TOP}"| cut -f 2)
  echo -e "The value of ${LBLUE}MISP.welcome_text_top${NC} is: ${YELLOW}${VALUE}${NC}\n"
  echo "Here is the description of the setting: ${DESCRIPTION}"
  space
  CAKE_TEXT_BOTTOM=$(${CAKE} Admin getSetting "MISP.welcome_text_bottom" |tail -n +7 |jq -r '[.description,.value] |@tsv')
  DESCRIPTION=$(echo "${CAKE_TEXT_BOTTOM}"| cut -f 1)
  VALUE=$(echo "${CAKE_TEXT_BOTTOM}"| cut -f 2)
  echo -e "The value of ${LBLUE}MISP.welcome_text_bottom${NC} is: ${YELLOW}${VALUE}${NC}\n"
  echo "Here is the description of the setting: ${DESCRIPTION}"
  space
  space
  for setting in $(echo "footermidleft footermidright welcome_text_top welcome_text_bottom"); do
    echo -e -n "Please enter text for '${LBLUE}${setting}${NC}' (Enter for blank): "
    read VALUE
    if [ -z "${VALUE}" ]; then
      ${CAKE} Admin setSetting "MISP.${setting}" false
    else
      ${CAKE} Admin setSetting "MISP.${setting}" "${VALUE}"
    fi
  done

  rc "All done."
}

regen-cert () {
  CAKE_ORG=$(${CAKE} Admin getSetting "MISP.org" |tail -n +7 |jq -r '[.description,.value] |@tsv')
  VALUE=$(echo "${CAKE_ORG}"| cut -f 2)
  OPENSSL_O=${VALUE}

  ask_o "Using ${YELLOW}${FQDN}${NC} as common name (CN), do you want to change it?"
  if [[ "${ANSWER}" == "y" ]]; then
    echo -n "Please enter the certificate common name: "
    read OPENSSL_CN
  fi

  ask_o "Using ${YELLOW}${OPENSSL_EMAILADDRESS}${NC} as contact email for the certificate, do you want to change it?"
  if [[ "${ANSWER}" == "y" ]]; then
    echo -n "Please enter the certificate contact email: "
    read OPENSSL_EMAILADDRESS
  fi

  getOrgInfo
  OPENSSL_O=$(echo ${orgInfo} |jq -r .Organisation.name)
  ask_o "Using ${YELLOW}${OPENSSL_O}${NC} as Organisation, do you want to change it?"
  if [[ "${ANSWER}" == "y" ]]; then
    echo -n "Please enter the certificate Organisation: "
    read OPENSSL_O
  fi

  ask_o "Using ${YELLOW}${OPENSSL_C}${NC} as ISO Country Code, do you want to change it?"
  if [[ "${ANSWER}" == "y" ]]; then
    echo -n "Please enter the ISO Country Code for the certificate: "
    read OPENSSL_O
  fi

  sudo openssl req -newkey rsa:4096 -days 365 -nodes -x509 \
  -subj "/C=${OPENSSL_C}/O=${OPENSSL_O}/CN=${OPENSSL_CN}/emailAddress=${OPENSSL_EMAILADDRESS}" \
  -keyout /etc/ssl/private/misp.local.key -out /etc/ssl/private/misp.local.crt
  sudo systemctl restart apache2

  rc "New self-signed certificate created.\nPlease consider using a Signed-ish certificate like https://letsencrypt.org/"
}

regen-ssh () {
  echo "Removing: /etc/ssh/ssh_host_* (forcefully)"
  sudo rm -vf /etc/ssh/ssh_host_*

  # Check if we can handle the firstBoot script, else just regen NOW
  if [ "$(grep firstBoot /etc/rc.local > /dev/null 2>&1 ; echo $?)" != "0" ]; then
    sudo /usr/sbin/dpkg-reconfigure openssh-server
  else
    echo '#!/bin/bash
/usr/sbin/dpkg-reconfigure openssh-server
rm $0' |sudo tee /etc/init.d/firstBoot
    sudo chmod +x /etc/init.d/firstBoot
  fi
  rc "Please reboot to regenerate SSH keys."
}

regen-gpg () {
  echo "Removing '${PATH_TO_MISP}/.gnupg' (forcefully)"
  sudo rm -rf ${PATH_TO_MISP}/.gnupg

  echo -n "Please enter a 'Real Name' for your GPG Key. (misppriv@circl.lu uses: MISP CIRCL for Private Sector): "
  read GPG_REAL_NAME
  echo -n "Enter an E-Mail address for the Key: "
  read GPG_EMAIL_ADDRESS
  ask_o "The Autogenerated Password for this key is: '${YELLOW}${GPG_PASSPHRASE}${NC}'. Do you want to change it?"
  if [[ "${ANSWER}" == "y" ]]; then
    echo -n "Please enter a Passphrase for the GPG Key: "
    read GPG_PASSPHRASE
  fi

  echo "%echo Generating a default key
      Key-Type: default
      Key-Length: ${GPG_KEY_LENGTH}
      Subkey-Type: default
      Name-Real: ${GPG_REAL_NAME}
      Name-Comment: ${GPG_COMMENT}
      Name-Email: ${GPG_EMAIL_ADDRESS}
      Expire-Date: 0
      Passphrase: ${GPG_PASSPHRASE}
      # Do a commit here, so that we can later print "done"
      %commit
    %echo done" > /tmp/gen-key-script


  echo "The generation WILL take some time, please be patient."
  ${SUDO_WWW} gpg --homedir ${PATH_TO_MISP}/.gnupg --batch --gen-key /tmp/gen-key-script

  # Export the public key to the webroot
  ${SUDO_WWW} sh -c "gpg --homedir ${PATH_TO_MISP}/.gnupg --export --armor ${GPG_EMAIL_ADDRESS}" | ${SUDO_WWW} tee ${PATH_TO_MISP}/app/webroot/gpg.gpg.asc
  ${CAKE} Admin setSetting "GnuPG.email" "${GPG_EMAIL_ADDRESS}"
  ${CAKE} Admin setSetting "GnuPG.password" "${GPG_PASSPHRASE}"

  rc "New GPG key created."
}

cleanUp () {
  rm /tmp/edit_user_json.py
  rm /tmp/keys.py /tmp/getOrgInfo.py /tmp/getUserInfo.py
  rm /tmp/orga.json /tmp/user.json
  rm -f /tmp/gen-key-script
  rm /tmp/refresh.sh
}
# Functions section end

# Main section begin

if [ ! -z "${DIALOG}" ]; then
  OPTIONS=$(dialog --checklist --output-fd 1 "Choose what operations to perform:" 15 60 7 \
        wipe "Wipe MISP instance" off \
        baseU "Reset BaseURL" off \
        baseO "Reset Base Organisation" off \
        texts "Reset Welcome Texts and Footers" off \
        purgeLog "Purge Log Files" off \
        SSL "Regenerate self-signed SSL Cert " off \
        SSH "Regenerate SSH server key" off \
        GPG "Regenerate MISP GPG Key" off)
#        upd "Update MISP" off \
fi

# Enable colors
colors

# TODO: Test and implement properly
#[[ -z "${DIALOG}" ]] && ask_o "Do you want to reset the ${LBLUE}MISP${NC} Admin Password?" && [[ "${ANSWER}" == "y" ]] && resetAdmin
#case $OPTIONS in *"wipe"*) misp-wipe ;; esac

# Use misp-wipe.sh to clean everything
[[ -z "${DIALOG}" ]] && ask_o "Do you want to wipe this ${LBLUE}MISP${NC} instance?" && [[ "${ANSWER}" == "y" ]] && misp-wipe
case ${OPTIONS} in *"wipe"*) misp-wipe ;; esac

[[ -z "${DIALOG}" ]] && ask_o "Do you want to reset the BaseURL?" && [[ "${ANSWER}" == "y" ]] && reset-baseurl
case ${OPTIONS} in *"baseU"*) reset-baseurl ;; esac

[[ -z "${DIALOG}" ]] && ask_o "Do you want to reset the Base Organisation?" && [[ "${ANSWER}" == "y" ]] && reset-org
case ${OPTIONS} in *"baseO"*) reset-org ;; esac

[[ -z "${DIALOG}" ]] && ask_o "Do you want to reset the welcome texts and footers?" && [[ "${ANSWER}" == "y" ]] && reset-texts
case ${OPTIONS} in *"texts"*) reset-texts ;; esac

[[ -z "${DIALOG}" ]] && ask_o "Do you want to purge the log files?" && [[ "${ANSWER}" == "y" ]] && purge-log
case ${OPTIONS} in *"purgeLog"*) purge-log ;; esac

[[ -z "${DIALOG}" ]] && ask_o "Do you want to regenerate the self-signed SSL certificate?" && [[ "${ANSWER}" == "y" ]] && regen-cert
case ${OPTIONS} in *"SSL"*) regen-cert ;; esac

[[ -z "${DIALOG}" ]] && ask_o "Do you want to regenerate the SSH server keys?" && [[ "${ANSWER}" == "y" ]] && regen-ssh
case ${OPTIONS} in *"SSH"*) regen-ssh ;; esac

[[ -z "${DIALOG}" ]] && ask_o "Do you want to regenerate the ${LBLUE}MISP${NC} GPG keys?" && [[ "${ANSWER}" == "y" ]] && regen-gpg
case ${OPTIONS} in *"GPG"*) regen-gpg ;; esac

#ask_o "Do you want to update MISP?
#[[ "${ANSWER}" == "y" ]] && misp-update
#case ${OPTIONS} in *"upd"*) misp-update ;; esac

cleanUp > /dev/null 2>&1

# Main section end
