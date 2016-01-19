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
VAGRANT_TOOLS="${BASE_PATH}vagrant.sh"
FORMATTING_TOOLS=()
DETACHED_RUNNER="${BASE_PATH}/cache/detach/"

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

if [ -n "$ENABLE_VAGRANT" ] && [ "$ENABLE_VAGRANT" = true ]; then
    source "${VAGRANT_TOOLS}"
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

function detach ()
{
    currentDir=`pwd`
    projectFolder=`getProjectFolder`
    if [ $? -ne 0 ]; then
        echo -e "\033[31mSorry, not in a Git project. This method works only for Git projects.\033[0m"
        return 1
    fi
    projectFolder="${projectFolder}/"

    echo -ne "\033[36mDetaching...\033[0m"\\r
    mkdir -p "${DETACHED_RUNNER}${projectFolder}"
    eval "rsync -a --delete --exclude=/.git/ ${projectFolder} ${DETACHED_RUNNER}${projectFolder}"
    echo -e "\033[32mDetached!   \033[0m"\\r

    cd "${DETACHED_RUNNER}${projectFolder}"
    eval "$@"
    cd "${currentDir}"
}