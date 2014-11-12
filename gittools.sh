#!/bin/sh

function getGitBranch ()
{
    GIT_SYM=`git symbolic-ref HEAD`
    echo "${GIT_SYM##refs/heads/}"
}

function gitCreateCommit ()
{
    git add --all
    git commit -m "$1" --quiet
}

function gitPushChanges ()
{
    git push origin $(getGitBranch) --quiet
}

if [ -n "$ENABLE_ALIAS" ] && [ "$ENABLE_ALIAS" = true ]; then
    alias gclone="git clone"
    alias gstatus="git status"
    alias gpush="git push origin \$(getGitBranch)"
    alias gpull="git pull origin \$(getGitBranch)"
    alias gadd="git add"
    alias gcommit="git commit"
    alias gco="git checkout"
    alias gfetch="git fetch"
    alias gtree="git log --graph --pretty=oneline --abbrev-commit"
    alias gdiff="git diff"
    alias gmerge="git merge"
    alias gbranch="git branch"
    alias gstash="git stash"
    alias grebase="git rebase"
    alias greset="git reset"
    alias grm="git rm"

    function gclean ()
    {
        if [ "`askQuestion 'Are you sure you want to clean your environment' 'Y'`" = true ]; then
            git clean -dfq
            git checkout -- .

            echo -e "\033[32mEnvironment clean\033[0m"
        else
            echo -e "\033[31mAborted...\033[0m"
        fi
    }

    function gtag ()
    {
        name=`askMessage 'Tag name:'`
        message=`askMessage 'Tag message:'`

        git tag -a "$name" -m "$message"
        echo -e "\033[32mTag successfully created\033[0m"


        if [ "`askQuestion 'Do you want to push it to the server' 'Y'`" = true ]; then
            git push origin "$name" --no-verify --quiet
            echo -e "\033[32mTag pushed to server\033[0m"
        fi
    }
fi