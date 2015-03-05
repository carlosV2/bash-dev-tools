#!/bin/sh

function askQuestion ()
{
    yes="y"
    no="n"
    if [ "$2" = "Y" ]; then
        yes="Y"
    else
        no="N"
    fi

    read -p "$1? [$yes/$no] " decision

    if [ "$2" = "Y" ]; then
        if [ "$decision" = "" ] || [ "$decision" = "Y" ] || [ "$decision" = "y" ]; then
            echo true
        else
            echo false
        fi
    else
        if [ "$decision" = "" ] || [ "$decision" = "N" ] || [ "$decision" = "n" ]; then
            echo false
        else
            echo true
        fi
    fi
}

function askMessage ()
{
    read -p "$1 " message
    echo "$message"
}

if [ -z "$BASE_PATH" ]; then
    BASE_PATH="~/.bash-dev-tools/"
fi

GIT_TOOLS="${BASE_PATH}gittools.sh"
SYMFONY_TOOLS="${BASE_PATH}symfonytools.sh"
BEHAT_TOOLS="${BASE_PATH}behattools.sh"
PHPSPEC_TOOLS="${BASE_PATH}phpspectools.sh"
FORMATTING_TOOLS=()

if [ -n "$ENABLE_GIT" ] && [ "$ENABLE_GIT" = true ]; then
    source "${GIT_TOOLS}"
fi

if [ -n "$ENABLE_SYMFONY" ] && [ "$ENABLE_SYMFONY" = true ]; then
    source "${SYMFONY_TOOLS}"
fi

if [ -n "$ENABLE_BEHAT" ] && [ "$ENABLE_BEHAT" = true ]; then
    source "${BEHAT_TOOLS}"
fi

if [ -n "$ENABLE_PHPSPEC" ] && [ "$ENABLE_PHPSPEC" = true ]; then
    source "${PHPSPEC_TOOLS}"
fi

if [ -n "$ENABLE_ALIAS" ] && [ "$ENABLE_ALIAS" = true ]; then
    function ff ()
    {
        if [ -f "bin/php-cs-fixer" ]; then
            changes=0
            for tool in ${FORMATTING_TOOLS[@]}; do
                $tool
                changed=$?
                changes=$((changes + changed))
            done

            if [ $changes -gt 0 ] && [ "$ENABLE_GIT" = true ]; then
                if [ "`askQuestion 'Do you want to commit changes' 'Y'`" = "true" ]; then
                    gitCreateCommit "Fix formatting"
                    echo -e "\033[32mCommit created\033[0m"

                    if [ "`askQuestion 'Do you want to push changes' 'Y'`" = "true" ]; then
                        gitPushChanges
                        echo -e "\033[32mCommit pushed to code repository\033[0m"
                    fi
                fi
            fi
        fi
    }
fi