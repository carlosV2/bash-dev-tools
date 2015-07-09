#!/bin/sh

function getFileChecksum ()
{
    sha=`shasum $1 2> /dev/null`
    if [ $? -ne 0 ]; then
        echo ""
    fi

    prefix=" $1"
    echo "${sha%$prefix}"
}

function getProjectFolder ()
{
    gitFolder=`command git rev-parse --git-dir 2> /dev/null`
    if [ $? -ne 0 ]; then
        return 1
    elif [ "${gitFolder}" = ".git" ]; then
        gitFolder=`pwd`
    else
        gitFolder=${gitFolder%.git}
    fi

    echo "${gitFolder}"

    return 0
}

function runFilePatchesProcess ()
{
    projectFolder=`getProjectFolder`
    if [ $? -eq 0 ]; then
        patchesFolder="$1"
        if [ -d "${patchesFolder}" ] && [ -d "${patchesFolder}${projectFolder}" ]; then
            for file in `find "${patchesFolder}${projectFolder}" -type f`; do
                projectFile="${file#${patchesFolder}}"

                result=`patch -sN --dry-run "${projectFile}" < "${file}" >&1`
                if [ $? -ne 0 ]; then
                    echo -e "\033[31mFile \`${file#${patchesFolder}}\` could not be patched. Please, review it. Error: $result\033[0m"

                    return 1
                fi
            done

            for file in `find "${patchesFolder}${projectFolder}" -type f`; do
                projectFile="${file#${patchesFolder}}"

                patch -sN "${projectFile}" < "${file}" 2> /dev/null
            done
        fi
    fi

    return 0
}

function gitCmd ()
{
    runFilePatchesProcess "${GIT_PATCHES_DOWN_FOLDER}"

    if [ $? -eq 0 ]; then
        git "$@"
        result=$?

        runFilePatchesProcess "${GIT_PATCHES_UP_FOLDER}"

        return $result
    fi

    return 256
}

function getGitBranch ()
{
    GIT_SYM=`gitCmd symbolic-ref HEAD`
    echo "${GIT_SYM##refs/heads/}"
}

function gitCreateCommit ()
{
    gitCmd add --all
    gitCmd commit -m "$1" --quiet
}

function gitPushChanges ()
{
    gitCmd push origin $(getGitBranch) --quiet
}

function getGitProjectFolder ()
{
    gitCmd rev-parse --show-toplevel
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
            gitCmd log -${commits} --oneline
            echo

            if [ "`askQuestion 'Are you sure you want to export them' 'Y'`" = true ]; then
                gitCmd log -${commits} --oneline | cut -d' ' -f2- > "${GIT_PORTATION_COMMITS_FILE}"

                for i in `seq 1 ${commits}`; do
                    echo -ne "Saving commit (${i}/${commits})        "\\r
                    gitCmd reset HEAD~1 --quiet && gitCmd stash -u --quiet
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
                gitCmd stash drop --quiet 2> /dev/null
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
        numberOfChanges=`gitCmd status --porcelain | wc -l`
        if [ $numberOfChanges -gt 0 ]; then
            changes=`gitCmd status --porcelain | cut -c1-2`
            clean=true
            for line in ${changes}; do
                if [ "$line" != "M" ] && [ "$line" != "??" ] && [ "$line" != "A" ] && [ "$line" != "R" ]; then
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
                    gitCmd stash drop --quiet

                    continueFileContent=`cat "${GIT_PORTATION_CONTINUE_FILE}"`
                    rm "${GIT_PORTATION_CONTINUE_FILE}"

                    if [ "${continueFileContent}" = "all" ]; then
                        gitImportAll
                    fi
                fi
            else
                echo -e "\033[33mSome files need your supervision. Please check the following list:\033[0m"
                gitCmd status --porcelain

                touch "${GIT_PORTATION_CONTINUE_FILE}"
            fi
        else
            echo -e "\033[36mThere are no changes registered. This commit will be skipped.\033[0m"

            numberOfCommits=`cat "${GIT_PORTATION_COMMITS_FILE}" | wc -l | xargs`
            numberOfCommits=$((numberOfCommits - 1))
            if [ $numberOfCommits -lt 1 ]; then
                rm -rf "${GIT_PORTATION_COMMITS_FILE}"
            else
                commits=`head -$numberOfCommits "${GIT_PORTATION_COMMITS_FILE}"`
                echo "$commits" > "${GIT_PORTATION_COMMITS_FILE}"
            fi
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
            commit=`tail -1 "${GIT_PORTATION_COMMITS_FILE}"`
            echo -e "Applying: \033[33m${commit}\033[0m"

            gitCmd stash pop --quiet > /dev/null
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
            gitImportOne

            if [ -f "${GIT_PORTATION_COMMITS_FILE}" ]; then
                if [ ! -f "${GIT_PORTATION_CONTINUE_FILE}" ]; then
                    gitImportAll
                else
                    echo "all" > "${GIT_PORTATION_CONTINUE_FILE}"
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
GIT_PATCHES_CACHE_FOLDER="${BASE_PATH}/cache/patches/"
GIT_PATCHES_FOLDER="${BASE_PATH}/patches/"
GIT_PATCHES_UP_FOLDER="${BASE_PATH}/patches/up/"
GIT_PATCHES_DOWN_FOLDER="${BASE_PATH}/patches/down/"

if [ -n "$ENABLE_ALIAS" ] && [ "$ENABLE_ALIAS" = true ]; then
    alias git="gitCmd"
    alias ogit="command git"
    alias gclone="git clone"
    alias gstatus="git status"
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

    function gpush ()
    {
        folder=`getGitProjectFolder`
        rebaseMergeTest="$folder/.git/rebase-merge"
        rebaseApplyTest="$folder/.git/rebase-apply"

        test -d "$rebaseMergeTest" -o -d "$rebaseApplyTest"
        if [ $? -ne 0 ]; then
            branch=`getGitBranch`
            gitCmd push origin "$branch" "$@"
        else
            echo -e "\033[31mYou cannot PUSH commits while rebasing\033[0m"
        fi
    }

    function gpull ()
    {
        folder=`getGitProjectFolder`
        rebaseMergeTest="$folder/.git/rebase-merge"
        rebaseApplyTest="$folder/.git/rebase-apply"

        test -d "$rebaseMergeTest" -o -d "$rebaseApplyTest"
        if [ $? -ne 0 ]; then
            branch=`getGitBranch`
            gitCmd pull origin "$branch" "$@"
        else
            echo -e "\033[31mYou cannot PULL commits while rebasing\033[0m"
        fi
    }

    function gclean ()
    {
        if [ "`askQuestion 'Are you sure you want to clean your environment' 'Y'`" = true ]; then
            gitCmd reset HEAD --quiet
            gitCmd clean -dfq
            gitCmd checkout -- .

            echo -e "\033[32mEnvironment clean\033[0m"
        else
            echo -e "\033[31mAborted...\033[0m"
        fi
    }

    function gtag ()
    {
        name=`askMessage 'Tag name:'`
        message=`askMessage 'Tag message:'`

        gitCmd tag -a "$name" -m "$message"
        echo -e "\033[32mTag successfully created\033[0m"

        if [ "`askQuestion 'Do you want to push it to the server' 'Y'`" = true ]; then
            gitCmd push origin "$name" --no-verify --quiet
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

    function generatePatchFilesForCurrentProject ()
    {
        projectFolder=`getProjectFolder`
        if [ $? -ne 0 ]; then
            echo -e "\033[31mSorry, not in a Git project. This method works only for Git projects.\033[0m"
            return 1
        fi
        projectFolder="${projectFolder}/"

        if [ -d "${GIT_PATCHES_UP_FOLDER}${projectFolder}" ] || [ -d "${GIT_PATCHES_DOWN_FOLDER}${projectFolder}" ]; then
            if [ "`askQuestion 'This will remove previous patches. Do you want to continue' 'N'`" = false ]; then
                return 1
            fi

            rm -rf "${GIT_PATCHES_UP_FOLDER}${projectFolder}"
            rm -rf "${GIT_PATCHES_DOWN_FOLDER}${projectFolder}"
        fi

        echo -n "Preparing environment... "
        if [ -d "${GIT_PATCHES_CACHE_FOLDER}" ]; then
            rm -rf "${GIT_PATCHES_CACHE_FOLDER}"
        fi

        rsyncExclusions=""
        if [ -f "${projectFolder}/.bdtignore" ]; then
            rsyncExclusions=`echo $(cat .bdtignore | sed -e 's/^[^!]/--exclude=\//' | sed -e 's/^!/--include=/')`
        fi
        eval "rsync -a ${rsyncExclusions} ${projectFolder} ${GIT_PATCHES_CACHE_FOLDER}"

        echo -e "\033[32mdone\033[0m"
        echo
        read -p "Please, modify the project now and press enter when done..." tmp

        echo -n "Checking files... "
        for file in `find "${GIT_PATCHES_CACHE_FOLDER}" -type f`; do
            projectFile="${projectFolder}${file#${GIT_PATCHES_CACHE_FOLDER}}"

            fileChecksum=`getFileChecksum "$projectFile"`
            cachedFileChecksum=`getFileChecksum "$file"`

            if [ "$fileChecksum" != "$cachedFileChecksum" ]; then
                basePath=$(dirname "$projectFile")
                mkdir -p "${GIT_PATCHES_UP_FOLDER}${basePath}"
                mkdir -p "${GIT_PATCHES_DOWN_FOLDER}${basePath}"

                diff "$file" "$projectFile" > "${GIT_PATCHES_UP_FOLDER}${projectFile}"
                diff "$projectFile" "$file" > "${GIT_PATCHES_DOWN_FOLDER}${projectFile}"
            fi
        done

        echo -e "\033[32mdone\033[0m"

        echo
        echo "Patches created. Have fun developing!"
    }

    function applyProjectPatches ()
    {
        getProjectFolder > /dev/null
        if [ $? -ne 0 ]; then
            echo -e "\033[31mSorry, not in a Git project. This method works only for Git projects.\033[0m"
            return 1
        fi

        case "$1" in
            up)
                if [ "`askQuestion 'Are you sure you want to apply the UP patches' 'Y'`" = true ]; then
                    runFilePatchesProcess "${GIT_PATCHES_UP_FOLDER}"
                fi
                ;;
            down)
                if [ "`askQuestion 'Are you sure you want to apply the DOWN patches' 'Y'`" = true ]; then
                    runFilePatchesProcess "${GIT_PATCHES_DOWN_FOLDER}"
                fi
                ;;
            *)
                echo -e "\033[31mPlease, specify the patches you want to apply:\n\nUsage: applyProjectPatches [up|down].\033[0m"
                ;;
        esac
    }
fi
