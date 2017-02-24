#!/bin/sh

function fixFormattingOnSrcFiles ()
{
    echo -ne "Fixing SRC files... \033[36mcleaning\033[0m"\\r
    phpcsfixerBinary fix src --quiet
    if [ $? -eq 0 ]; then
        echo -e "Fixing SRC files... \033[32mclean   \033[0m"
        return 0
    else
        echo -e "Fixing SRC files... \033[33mfixed   \033[0m"
        return 1
    fi
}

FORMATTING_TOOLS+=('fixFormattingOnSrcFiles')

if [ -n "$ENABLE_ALIAS" ] && [ "$ENABLE_ALIAS" = true ]; then
    alias ccache="rm -rf app/cache/*"
    alias clogs="rm -rf app/logs/*"
    alias call="ccache && clogs"
    alias ac="app/console"

    function composer ()
    {
        if [ ! -f "composer.phar" ]; then
            curl -sS https://getcomposer.org/installer | php > /dev/null 2>&1
            if [ ! -f "composer.phar" ]; then
                echo -e "\033[31mUnable to download a copy of composer.\033[0m"
                return 1;
            fi
        fi

        #php composer.phar self-update > /dev/null 2>&1

        php composer.phar "$@"

        return $?
    }
fi
