#!/bin/bash

C='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # No Color

###########################################################################
cd -- "$(dirname "$BASH_SOURCE")"

###########################################################################
folder=$(basename "`pwd`")
if [ $folder == "scripts" ]
then
    cd ..
fi
clear

##########################################################################
FILE=.sfdx/sfdx-config.json
if [ ! -f "$FILE" ]; then
    echo "${RED}DevHub not authenticated. Please login using your DX user.${NC}"
    sfdx force:auth:web:login -d
    echo
else
    if [ $(jq -r 'has("defaultdevhubusername")' ./.sfdx/sfdx-config.json) == false ]; then
        echo "${RED}DevHub not authenticated. Please login using your DX user.${NC}"
        sfdx force:auth:web:login -d
        echo
    fi
fi

##########################################################################
FILE=.ssdx/.packageKey
if [ ! -f "$FILE" ]; then
    echo "${RED}Package Key is missing. ${NC}"
    read -p 'What is the value? '
    echo $REPLY > .ssdx/.packageKey
    echo
fi

##########################################################################
if [ -z "$1" ]
then
    read -p 'Scratch org name: '
else
    REPLY=$1
fi

##########################################################################
echo && echo "${C}Creating Scratch Org named '$REPLY' ${NC}..."
sfdx force:org:create -f ./config/project-scratch-def.json --setalias $REPLY --durationdays 5 --setdefaultusername >/dev/null 2>&1

##########################################################################
echo && echo "${C}Installing Managed Packages ${NC}..."
for PACKAGE_ID in $(cat config/ssdx-config.json | jq -r 'try .managed_packages[]'); do
    echo "  - Installing $PACKAGE_ID"
    sfdx force:package:install -r --publishwait 60 --wait 60 -p $PACKAGE_ID >/dev/null 2>&1
done

###########################################################################
echo && echo "${C}Installing Unlocked Packages ${NC}..."
echo y | sfdx plugins:install @dx-cli-toolbox/sfdx-toolbox-package-utils >/dev/null 2>&1
KEY=$(cat .ssdx/.packageKey)
KEYS="1:$KEY 2:$KEY 3:$KEY 4:$KEY 5:$KEY 6:$KEY 7:$KEY 8:$KEY 9:$KEY 10:$KEY 11:$KEY 12:$KEY 13:$KEY 14:$KEY 15:$KEY 16:$KEY 17:$KEY 18:$KEY 19:$KEY 20:$KEY"
sfdx toolbox:package:dependencies:install --installationkeys "$KEYS" --targetusername $REPLY --wait 20

###########################################################################
echo && echo "${C}Pushing Metadata ${NC}..."
sfdx force:source:push >/dev/null 2>&1

###########################################################################
echo && echo "${C}Opening Scratch Org ${NC}..."
sfdx force:org:open >/dev/null 2>&1

###########################################################################
echo && echo "${C}Sleeping for 60 seconds 😴 ${NC}..."
sleep 60 >/dev/null 2>&1

###########################################################################
echo && echo "${C}Assigning Permission Set ${NC}..."
for PERMSET in $(cat config/ssdx-config.json | jq -r '.permsets_to_assign[]'); do
    echo "  - Assigning $PERMSET"
    sfdx force:user:permset:assign -n $PERMSET >/dev/null 2>&1
done