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

function gitExportInit ()
{
    if [ ! -f "${GIT_PORTATION_COMMITS_FILE}" ]; then
        commits=$1
        if [ "$commits" = "" ]; then
            commits=0
        fi

        if [ $commits -ge 1 ]; then
            echo -e "\033[32mYou are about to export the following commits:\033[0m"
            git log -${commits} --oneline
            echo

            if [ "`askQuestion 'Are you sure you want to export them' 'Y'`" = true ]; then
                git log -${commits} --oneline | cut -d' ' -f2- > "${GIT_PORTATION_COMMITS_FILE}"

                for i in `seq 1 ${commits}`; do
                    echo -ne "Saving commit (${i}/${commits})        "\\r
                    git reset HEAD~1 --quiet && git stash -u --quiet
                done

                echo -e "\033[32mCommits exported successfully!\033[0m"
            fi
        else
            echo -e "\033[33mPlease, supply the number of commits you want to export.\033[0m"
        fi
    else
        echo -e "\033[31mYou are already exporting some commits.\033[0m"
    fi
}

function gitExportAbort ()
{
    if [ -f "${GIT_PORTATION_COMMITS_FILE}" ]; then
        if [ "`askQuestion 'Are you sure you want to abort exporting' 'Y'`" = true ]; then
            commits=`cat ${GIT_PORTATION_COMMITS_FILE} | wc -l | xargs`
            for i in `seq 1 ${commits}`; do
                echo -ne "Removing commit (${i}/${commits})        "\\r
                git stash drop --quiet 2> /dev/null
            done

            rm -rf "${GIT_PORTATION_COMMITS_FILE}"
            if [ -f "${GIT_PORTATION_CONTINUE_FILE}" ]; then
                rm -rf "${GIT_PORTATION_CONTINUE_FILE}"
            fi

            echo -e "\033[32mExport aborted. Please, ensure you have all the commits in place.\033[0m"
        fi
    else
        echo -e "\033[31mNot any export operation started.\033[0m"
    fi
}

function gitImportContinue ()
{
    if [ -f "${GIT_PORTATION_COMMITS_FILE}" ]; then
        numberOfChanges=`git status --porcelain | wc -l`
        if [ $numberOfChanges -gt 0 ]; then
            changes=`git status --porcelain | cut -c1-2`
            clean=true
            for line in ${changes}; do
                if [ "$line" != "M" ] && [ "$line" != "??" ] && [ "$line" != "A" ]; then
                    clean=false
                fi
            done

            if [ ${clean} = true ]; then
                numberOfCommits=`cat "${GIT_PORTATION_COMMITS_FILE}" | wc -l | xargs`
                lastCommit=`tail -1 "${GIT_PORTATION_COMMITS_FILE}"`

                gitCreateCommit "${lastCommit}"

                numberOfCommits=$((numberOfCommits - 1))
                if [ $numberOfCommits -lt 1 ]; then
                    rm -rf "${GIT_PORTATION_COMMITS_FILE}"
                else
                    commits=`head -$numberOfCommits "${GIT_PORTATION_COMMITS_FILE}"`
                    echo "$commits" > "${GIT_PORTATION_COMMITS_FILE}"
                fi

                if [ -f "${GIT_PORTATION_CONTINUE_FILE}" ]; then
                    git stash drop --quiet
                    rm "${GIT_PORTATION_CONTINUE_FILE}"
                fi
            else
                echo -e "\033[33mSome files need your supervision. Please check the following list:\033[0m"
                git status --porcelain

                touch "${GIT_PORTATION_CONTINUE_FILE}"
            fi
        else
            echo -e "\033[31mThere are no changes registered. Are you missing something?\033[0m"
        fi
    else
        echo -e "\033[31mNot any export operation started.\033[0m"
    fi
}

function gitImportOne ()
{
    if [ -f "${GIT_PORTATION_COMMITS_FILE}" ]; then
        if [ -f "${GIT_PORTATION_CONTINUE_FILE}" ]; then
            echo -e "\033[31mAn import operation has started. Run \`gimport continue\` to resume it.\033[0m"
        else
            git stash pop --quiet
            gitImportContinue
        fi
    else
        echo -e "\033[31mNot any export operation started.\033[0m"
    fi
}

function gitImportAll ()
{
    if [ -f "${GIT_PORTATION_COMMITS_FILE}" ]; then
        if [ -f "${GIT_PORTATION_CONTINUE_FILE}" ]; then
            echo -e "\033[31mAn import operation has started. Run \`gimport continue\` to resume it.\033[0m"
        else
            commit=`tail -1 "${GIT_PORTATION_COMMITS_FILE}"`
            echo -e "Applying: \033[33m${commit}\033[0m"
            gitImportOne

            if [ -f "${GIT_PORTATION_COMMITS_FILE}" ]; then
                if [ ! -f "${GIT_PORTATION_CONTINUE_FILE}" ]; then
                    gitImportAll
                fi
            fi
        fi
    else
        echo -e "\033[31mNot any export operation started.\033[0m"
    fi
}

GIT_PORTATION_FOLDER="${BASE_PATH}/cache/gportation/"
GIT_PORTATION_COMMITS_FILE="${GIT_PORTATION_FOLDER}/commits"
GIT_PORTATION_CONTINUE_FILE="${GIT_PORTATION_FOLDER}/continue.lock"

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
    alias gmv="git mv"

    function gclean ()
    {
        if [ "`askQuestion 'Are you sure you want to clean your environment' 'Y'`" = true ]; then
            git reset HEAD --quiet
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

    function gexport ()
    {
        if [ ! -d "${GIT_PORTATION_FOLDER}" ]; then
            mkdir -p "${GIT_PORTATION_FOLDER}"
        fi

        case "$1" in
            abort)
                gitExportAbort
                ;;
            *)
                gitExportInit "$1"
                ;;
        esac
    }

    function gimport ()
    {
        if [ ! -d "${GIT_PORTATION_FOLDER}" ]; then
            mkdir -p "${GIT_PORTATION_FOLDER}"
        fi

        case "$1" in
            one)
                gitImportOne
                ;;
            continue)
                gitImportContinue
                ;;
            all)
                gitImportAll
                ;;
            *)
                echo -e "\033[31mPlease, select operation. Either \`one\`, \`continue\` or \`all\`.\033[0m"
                ;;
        esac
    }
fi
