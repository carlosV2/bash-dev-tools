#!/bin/sh

function fixFormattingOnPhpSpecFiles ()
{
    echo -n "Fixing SPEC files... "
    bin/php-cs-fixer fix --fixers=-visibility spec --quiet
    if [ $? -eq 0 ]; then
        echo -e "\033[32mclean\033[0m"
        return 0
    else
        echo -e "\033[33mfixed\033[0m"
        return 1
    fi
}

FORMATTING_TOOLS+=('fixFormattingOnPhpSpecFiles')

if [ -n "$ENABLE_ALIAS" ] && [ "$ENABLE_ALIAS" = true ]; then
    alias psr="bin/phpspec run"

    function psd ()
    {
        file="$1"
        len=`expr "$file" : 'src/'`
        if [ $len -gt 0 ]; then
            file="${file#src/}"
        else
            len=`expr "$file" : 'spec/'`
            if [ $len -gt 0 ]; then
                file="${file#spec/}"
            fi
        fi

        bin/phpspec desc "$file"
    }
fi