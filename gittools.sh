#!/bin/sh

function getFileChecksum ()
{
    md5=`md5 $1 2> /dev/null`
    if [ $? -eq 0 ]; then
        prefix="MD5 ($1) = "
        echo "${md5#$prefix}"
    else
        echo ""
    fi
}

function ensureSafeFilesAreTheSame ()
{
    folder="$1"
    for file in `find "${folder}" -type f`; do
        projectFile="${file#${folder}}"

        projectFileMd5=`getFileChecksum $projectFile`
        safeFileMd5=`getFileChecksum $file`

        if [ "$projectFileMd5" = "" ] || [ "$safeFileMd5" = "" ] || [ "$projectFileMd5" != "$safeFileMd5" ]; then
            return 1
        fi
    done

    return 0
}

function runSafeFilesRemoveProcess ()
{
    folder="$1"
    ensureSafeFilesAreTheSame "${folder}"
    if [ $? -ne 0 ]; then
        return 1
    fi

    for file in `find "${folder}" -type f`; do
        rm "${file#${folder}}"
    done

    return 0
}

function runSafeFilesCopyProcess ()
{
    folder="$1"
    for file in `find "${folder}" -type f`; do
        cp "$file" "${file#${folder}}"
    done
}

function gitCmd ()
{
    runSafeFilesRemoveProcess "${GIT_BEFORE_SAFE_FOLDER}"
    if [ $? -ne 0 ]; then
        echo -e "\033[31mSafe files are not in the status they should.\033[0m"
        return 1
    fi
    runSafeFilesCopyProcess "${GIT_AFTER_SAFE_FOLDER}"
    
    git "$@"

    runSafeFilesRemoveProcess "${GIT_AFTER_SAFE_FOLDER}"
    if [ $? -ne 0 ]; then
        echo -e "\033[31mAfter executing GIT the safe files are not in the status they should. Please, review the project status!\033[0m"
        return 1
    fi
    runSafeFilesCopyProcess "${GIT_BEFORE_SAFE_FOLDER}"

    return 0
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
GIT_SAFE_FOLDER="${BASE_PATH}/safe"
GIT_BEFORE_SAFE_FOLDER="${GIT_SAFE_FOLDER}/before/"
GIT_AFTER_SAFE_FOLDER="${GIT_SAFE_FOLDER}/after/"

if [ -n "$ENABLE_ALIAS" ] && [ "$ENABLE_ALIAS" = true ]; then
    alias git="gitCmd"
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

    function gitOverrideSafeFiles ()
    {
        if [ "`askQuestion 'Are you sure you want to override the safe files' 'N'`" = true ]; then
            runSafeFilesCopyProcess "${GIT_BEFORE_SAFE_FOLDER}"
            echo -e "\033[32mFiles overridden\033[0m"
        else
            echo -e "\033[31mAborted...\033[0m"
        fi
    }
fi
