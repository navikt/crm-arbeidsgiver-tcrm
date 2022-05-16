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
echo y | sfdx plugins:install sfpowerkit@2.0.1
keys="" && for p in $(sfdx force:package:list --json | jq '.result | .[].Name' -r); do keys+=$p":navcrm "; done
sfdx sfpowerkit:package:dependencies:install -u $REPLY -r -a -w 60 -k ${keys} --wait 20

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