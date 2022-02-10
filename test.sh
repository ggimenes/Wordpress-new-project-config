#!/bin/sh

# Version = 1.3.3
# 


CURRENTDIRECTORY=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
source $CURRENTDIRECTORY/config.cfg

# --------------------
# Set directory
# --------------------
cd $DIRECTORY

echo $DIRECTORY
ls

if [[ $SUBLIME_ENABLED == true ]]; then
    echo 'fail'
fi