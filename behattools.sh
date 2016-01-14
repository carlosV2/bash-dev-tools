#!/bin/sh

function addSnippetsIntoContext ()
{
    if [ ! -f "$1" ]; then
        echo -e "\033[31mFile '$1' does not exists033[0m"
    fi

    if [ ! -f "$2" ]; then
        echo -e "\033[31mFile '$2' does not exists033[0m"
    fi

    sed 's/^\(class .*\)$/use Behat\\Behat\\Context\\SnippetAcceptingContext;\'$'\n\\1,SnippetAcceptingContext/' "$2" > TemporalContext.php
    cat TemporalContext.php > "$2"

    bin/behat "$1" --append-snippets

    sed '/use Behat\\Behat\\Context\\SnippetAcceptingContext;/d' "$2" > TemporalContext.php
    cat TemporalContext.php > "$2"

    sed '/use Behat\\Behat\\Tester\\Exception\\PendingException;/d' "$2" > TemporalContext.php
    cat TemporalContext.php > "$2"

    sed 's/,SnippetAcceptingContext//' "$2" > TemporalContext.php
    cat TemporalContext.php > "$2"

    rm TemporalContext.php
}

function fixFormattingOnBehatFiles ()
{
    echo -ne "Fixing FEATURE files... \033[36mcleaning\033[0m"\\r
    bin/php-cs-fixer fix features --quiet
    if [ $? -eq 0 ]; then
        echo -e "Fixing FEATURE files... \033[32mclean   \033[0m"
        return 0
    else
        echo -e "Fixing FEATURE files... \033[33mfixed   \033[0m"
        return 1
    fi
}

function removeWipTagsFromFile ()
{
    file="$1"
    result=`cat "$file" | grep "@wip"`
    if [ "$result" != "" ]; then
        content=`cat "$file" | sed s/\ \@wip//g`
        echo "$content" > "$file"

        echo -e "Removed @WIP from \033[33m$file\033[0m"
    fi
}

function recursivelyRemoveWipTags ()
{
    folder="$1"
    for file in "$folder"/*; do
        if [ -d "$file" ]; then
            recursivelyRemoveWipTags "$file"
        else
            len=`expr "$file" : '.*\.feature$'`
            if [ $len -gt 0 ]; then
                removeWipTagsFromFile "$file"
            fi
        fi
    done
}

function generateNewRandomTmpDir ()
{
    seed=`php -r 'echo microtime(true) * 10000;'`
    generateNewTmpDirFromSeed "$seed"
}

function generateNewTmpDirFromSeed ()
{
    seed="$1"
    folder=`echo -n "$seed" | md5`

    mkdir "${TMPDIR}${folder}" 2> /dev/null
    echo "${TMPDIR}${folder}"
}

function executeBehat ()
{
    oldTmpDir="$TMPDIR"
    TMPDIR=`generateNewRandomTmpDir`

    bin/behat "$@"

    TMPDIR="${oldTmpDir}"
}

FORMATTING_TOOLS+=('fixFormattingOnBehatFiles')
CLEAN_BEHAT_CACHE_FOLDER="${BASE_PATH}/cache/cleanbh/"
CLEAN_BEHAT_CACHE_FILES_FOLDER="${BASE_PATH}/cache/cleanbh/files/"
CLEAN_BEHAT_EXTRA_FOLDER="${BASE_PATH}/extra/cleanbh/"
DETACHED_BEHAT_CACHE_FOLDER="${BASE_PATH}/cache/dbh/"

if [ -n "$ENABLE_ALIAS" ] && [ "$ENABLE_ALIAS" = true ]; then
    function bh()
    {
        if [ $# -eq 0 ]; then
            executeBehat -fprogress
        elif [ $# -eq 1 ]; then
            if [ -d "$1" ]; then
                executeBehat -fprogress "$1"
            else
                executeBehat -fpretty "$@"
            fi
        else
            executeBehat -fpretty "$@"
        fi
    }

    alias bhas="\$(addSnippetsIntoContext)"

    function rmwip ()
    {
        if [ $# -eq 1 ]; then
            if [ -f "$1" ]; then
                removeWipTagsFromFile "$1"
            elif [ -d "$1" ]; then
                recursivelyRemoveWipTags "$1"
            else
                echo -e "\033[31mFile \`$1\` does not exists or could not be opened.\033[0m"
            fi
        else
            recursivelyRemoveWipTags "features"
        fi
    }

    function cleanbh ()
    {
        runFilePatchesProcess "${GIT_PATCHES_DOWN_FOLDER}"

        echo -ne "Environment... \033[36mpreparing\033[0m"\\r
        if [ -d "${CLEAN_BEHAT_CACHE_FOLDER}" ]; then
            rm -rf "${CLEAN_BEHAT_CACHE_FOLDER}"
        fi
        mkdir -p "${CLEAN_BEHAT_CACHE_FOLDER}"
        echo -e "Environment... \033[32mready    \033[0m"

        echo -ne "Files... \033[36mpatching\033[0m"\\r
        for file in `find "features" -type f -name "*.php"`; do
            basePath=$(dirname "$file")

            mkdir -p "${CLEAN_BEHAT_CACHE_FILES_FOLDER}${basePath}"
            cp "$file" "${CLEAN_BEHAT_CACHE_FILES_FOLDER}${file}"

            php "${CLEAN_BEHAT_EXTRA_FOLDER}patch.php" "$file" "${CLEAN_BEHAT_EXTRA_FOLDER}inject.php" "${CLEAN_BEHAT_CACHE_FOLDER}logging.txt"
        done
        echo -e "Files... \033[32mpatched \033[0m"

        bh "$@"

        echo -ne "Files... \033[36mrestoring\033[0m"\\r
        for file in `find "features" -type f -name "*.php"`; do
            cp "${CLEAN_BEHAT_CACHE_FILES_FOLDER}${file}" "$file"
        done
        echo -e "Files... \033[32mrestored \033[0m"

        runFilePatchesProcess "${GIT_PATCHES_UP_FOLDER}"

        duplicatedSteps=`bh --no-colors -dl | cut -d"|" -f2 | sed -e 's/^ *//' -e '/^$/d' | grep -v -x -f "${CLEAN_BEHAT_CACHE_FOLDER}logging.txt"`
        if [ "$duplicatedSteps" == "" ]; then
            echo -e "\033[32mThere are no unused steps!\033[0m"
        else
            echo -e "\033[36mThese were the unused steps:\033[0m"
            echo
            echo "$duplicatedSteps"
        fi
    }

    function bhsearch ()
    {
        steps=`bh -dl | cut -d'|' -f2 | sort | uniq`
        total=`echo $(echo "$steps" | wc -l)`

        for arg in "$@"
        do
            param=""
            if [ "${arg:0:1}" == "-" ]; then
                arg="${arg:1}"
                param="-v"
            fi

            steps=`echo "$steps" | grep $param -i "$arg"`
        done

        if [ "$steps" == "" ]; then
            matches=0
        else
            echo "$steps"
            matches=`echo $(echo "$steps" | wc -l)`
            echo
        fi

        echo -e "Found \033[32m$matches\033[0m of \033[32m$total\033[0m total"
    }

    function dbh ()
    {
        currentDir=`pwd`
        projectFolder=`getProjectFolder`
        if [ $? -ne 0 ]; then
            echo -e "\033[31mSorry, not in a Git project. This method works only for Git projects.\033[0m"
            return 1
        fi
        projectFolder="${projectFolder}/"

        echo -ne "\033[36mDetaching...\033[0m"\\r
        copyFolder=`php -r 'echo microtime(true) * 10000;'`
        mkdir -p "${DETACHED_BEHAT_CACHE_FOLDER}${copyFolder}"
        eval "rsync -a --exclude=/.git/ ${projectFolder} ${DETACHED_BEHAT_CACHE_FOLDER}${copyFolder}"
        echo -e "\033[32mDetached!   \033[0m"\\r

        cd "${DETACHED_BEHAT_CACHE_FOLDER}${copyFolder}"
        bh "$@"

        echo -ne "\033[36mCleaning...\033[0m"\\r
        rm -rf "${DETACHED_BEHAT_CACHE_FOLDER}${copyFolder}"
        echo -e "\033[32mClean!     \033[0m"\\r

        cd "${currentDir}"
    }
fi