#!/bin/sh

function executeCommandInVagrant ()
{
    running=`vagrant status | grep running`
    if [ "$running" == "" ]; then
        vagrant up
    fi

    vagrant ssh -c "$*"
}

if [ -n "$ENABLE_ALIAS" ] && [ "$ENABLE_ALIAS" = true ]; then
    alias vmysql="executeCommandInVagrant mysql"
    alias vmongo="executeCommandInVagrant mongo"
    alias vcmd="executeCommandInVagrant"
    alias vcomposer="executeCommandInVagrant composer"
fi
