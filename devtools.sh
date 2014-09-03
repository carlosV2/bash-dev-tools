#!/bin/sh

function askQuestion ()
{
    yes="y"
    no="n"
    if [ "$2" == "Y" ]; then
        yes="Y"
    else
        no="N"
    fi

    echo -en "\033[33m$1? [$yes/$no] \033[0m"
    read decision

    if [ "$2" = "Y" ]; then
        if [ "$decision" = "" ] || [ "$decision" = "Y" ] || [ "$decision" = "y" ]; then
            echo true
        else
            echo false
        fi
    else
        if [ "$decision" = "" ] || [ "$decision" = "N" ] || [ "$decision" = "n" ]; then
            echo true
        else
            echo false
        fi
    fi
}

if [ -z "$BASE_PATH" ]; then
    BASE_PATH="~/.bash-dev-tools/"
fi

GIT_TOOLS="${BASE_PATH}gittools.sh"
SYMFONY_TOOLS="${BASE_PATH}symfonytools.sh"
BEHAT_TOOLS="${BASE_PATH}behattools.sh"
PHPSPEC_TOOLS="${BASE_PATH}phpspectools.sh"

if [ -n "$ENABLE_GIT" ] && [ "$ENABLE_GIT" = true ]; then
    source ${GIT_TOOLS}
fi

if [ -n "$ENABLE_SYMFONY" ] && [ "$ENABLE_SYMFONY" = true ]; then
    source ${SYMFONY_TOOLS}
fi

if [ -n "$ENABLE_BEHAT" ] && [ "$ENABLE_BEHAT" = true ]; then
    source ${BEHAT_TOOLS}
fi

if [ -n "$ENABLE_PHPSPEC" ] && [ "$ENABLE_PHPSPEC" = true ]; then
    source ${PHPSPEC_TOOLS}
fi