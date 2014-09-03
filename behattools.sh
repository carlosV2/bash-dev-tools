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

if [ -n "$ENABLE_ALIAS" ] && [ "$ENABLE_ALIAS" = true ]; then
    alias bhas="$(addSnippetsIntoContext)"
    alias bh="bin/behat"
fi