#!/bin/bash
#
# script to manage forked repos
# Maintainer: prabhjot@atsgen.com
#

DOMAIN='atsgen'

FILENAME='fork-list.txt'

GENERATE_REPO_LIST=0

REBASE_ALL_REPOS=0

REPO_DIR=''

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

function handle_repo {
    LOG_DIR=$PWD
    git clone git@github.com:atsgen/$REPO.git
    failed_branches=0
    pushd $REPO
    my_branches=($(git branch -a | grep origin | grep -v HEAD | awk '{split($0, a, "/"); print a[3]}'))
    for branch in ${my_branches[@]}
    do
        git checkout $branch --
    done
    git remote add upstream https://github.com/Juniper/$REPO.git
    git fetch upstream
    up_branches=($(git branch -a | grep upstream | grep -v HEAD | awk '{split($0, a, "/"); print a[3]}'))
    for branch in ${up_branches[@]}
    do
        git checkout $branch --
        git branch -a | grep origin/$branch > /dev/null
        if [[ $? -eq 0 ]]
        then
            git rebase upstream/$branch
        fi
        git status | grep up-to-date | grep origin > /dev/null
        if [[ $? -ne 0 ]]
        then
            echo "pushing branch to origin"
            git push origin $branch
            if [[ $? -ne 0 ]]
            then
                echo "failed to push branch $branch"
                echo "$REPO branch $branch" >> $LOG_DIR/failed.txt
                failed_branches=1
            else
                echo "$REPO branch $branch" >> $LOG_DIR/updated.txt
            fi
        else
            echo "$REPO branch $branch no change" >> $LOG_DIR/updated.txt
        fi
    done
    popd
    if [[ $failed_branches -eq 0 ]]
    then
        # remove repo only if there is no rebase error
        rm -rf $REPO
    fi
}

while getopts "rgh?d:" opt; do
    case "$opt" in
    h|\?)
        echo "$0   Usage: "
        echo "         -h  help"
        echo "         -g  force generate forked repo list"
        echo "         -r  rebase all the forked repos"
        echo "         -d <dir> directory to be used to checkout and rebase code"
        exit 0
        ;;
    g)  GENERATE_REPO_LIST=1
        ;;
    r)  REBASE_ALL_REPOS=1
        ;;
    d)  REPO_DIR=$OPTARG
        ;;
    esac
done

if [[ ! -f "$FILENAME" ]]
then
   echo "fork list does not exist, generating it"
   GENERATE_REPO_LIST=1
fi

if [[ $GENERATE_REPO_LIST -eq 1 ]]
then
    which curl >> /dev/null
    if [[ $? -ne 0 ]]
    then
        echo "curl: command not found, needed by utility"
        exit 1
    fi

    which jq >> /dev/null
    if [[ $? -ne 0 ]]
    then
        echo "jq: command not found, needed by utility"
        exit 1
    fi
    curl -s https://api.github.com/users/{$DOMAIN}/repos?per_page=1000 | jq '.[] | select(.fork==true) .name' | awk '{split($0, a, "\""); print a[2]}' > $FILENAME
fi

if [[ $REBASE_ALL_REPOS -eq 1 ]]
then
    IFS=$'\r\n' GLOBIGNORE='*' command eval  'REPO_LIST=($(cat $FILENAME))'
    if [[ -z $REPO_DIR ]]
    then
        echo "directory to checkout code is not specified"
        exit 1
    fi
    pushd $REPO_DIR
    if [[ $? -ne 0 ]]
    then
        exit 1
    fi
    for REPO in "${REPO_LIST[@]}"
    do
        handle_repo
    done
    popd
fi
