#!/bin/sh

function fixFormattingOnPhpSpecFiles ()
{
    echo -ne "Fixing SPEC files... \033[36mcleaning\033[0m"\\r

    IS_VISIBILITY_REQUIRED=`bin/php-cs-fixer help fix | grep visibility_required | wc -l`

    if [ $IS_VISIBILITY_REQUIRED -eq 0 ]; then
        bin/php-cs-fixer fix --fixers=-visibility spec --quiet
    else
        bin/php-cs-fixer fix --rules=-visibility_required spec --quiet
    fi

    if [ $? -eq 0 ]; then
        echo -e "Fixing SPEC files... \033[32mclean   \033[0m"
        return 0
    else
        echo -e "Fixing SPEC files... \033[33mfixed   \033[0m"
        return 1
    fi
}

function getLastEditedSpecFile ()
{
    environment=`uname -s`
    if [ "${environment}" = "Darwin" ]; then
        echo $(find spec -type f -print0 | xargs -0 stat -f "%m %N" | sort -rn | head -1 | cut -f2- -d" ")
    else
        echo $(find spec -type f -printf '%T@ %p\n' | sort -rn | head -1 | cut -f2- -d" ")
    fi
}

FORMATTING_TOOLS+=('fixFormattingOnPhpSpecFiles')

if [ -n "$ENABLE_ALIAS" ] && [ "$ENABLE_ALIAS" = true ]; then
    alias psr="bin/phpspec run"

    function psl ()
    {
        lastEdited=$(getLastEditedSpecFile)
        echo -e "Running phpspec for: \033[36m${lastEdited}\033[0m"
        bin/phpspec run "${lastEdited}"
    }

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
