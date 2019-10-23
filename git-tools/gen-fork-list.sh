#!/bin/bash

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

curl -s https://api.github.com/users/atsgen/repos?per_page=1000 | jq '.[] | select(.fork==true) .name' | awk '{split($0, a, "\""); print a[2]}'
