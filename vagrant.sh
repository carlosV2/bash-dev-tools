#!/bin/sh

function executeCommandInVagrant ()
{
    vagrant ssh -c "$*"
}

if [ -n "$ENABLE_ALIAS" ] && [ "$ENABLE_ALIAS" = true ]; then
    alias vmysql="executeCommandInVagrant mysql"
    alias vmongo="executeCommandInVagrant mongo"
    alias vcmd="executeCommandInVagrant"
    alias vcomposer="executeCommandInVagrant composer"
fi
