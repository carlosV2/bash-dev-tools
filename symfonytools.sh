#!/bin/sh

if [ -n "$ENABLE_ALIAS" ] && [ "$ENABLE_ALIAS" = true ]; then
    alias ccache="rm -rf app/cache/*"
    alias clogs="rm -rf app/logs/*"
    alias call="ccache && clogs"
    alias ac="app/console"
fi