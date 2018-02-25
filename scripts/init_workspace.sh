#!/bin/bash

# git submodule update
git config -f .gitmodules --get-regexp '^submodule\..*\.path$' |
while read path_key submodule_path; do
    # 
    # path => src/guthub.com/* 
    if echo $submodule_path | grep src/github.com > /dev/null 2>&1; then
        continue
    fi
    # git submodule add:
    #   path => vendor/github.com/*
    if echo $submodule_path | grep vendor/github.com > /dev/null 2>&1; then
        if [ ! -e $submodule_path ]; then
            url_key=$(echo $path_key | sed 's/\.path/.url/')
            submodule_url=$(git config -f .gitmodules --get "$url_key")
            git submodule add $submodule_url $submodule_path
        fi
    fi
done

# Add PATH
GOPATH=$PWD
if echo $PATH | grep $GOPATH/bin > /dev/null 2>&1; then
    :
else
    export PATH=$GOPATH/bin:$PATH
fi

# direnv
if [ -z "$DIRENV_DIR" ]; then
    export EDITOR=vim
    eval "$(direnv hook bash)"
fi




