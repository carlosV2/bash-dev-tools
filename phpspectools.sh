#!/bin/sh

if [ -n "$ENABLE_ALIAS" ] && [ "$ENABLE_ALIAS" = true ]; then
    alias psr="bin/phpspec run"
    alias psd="bin/phpspec desc"
fi