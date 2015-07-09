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
fi