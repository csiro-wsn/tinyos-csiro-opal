#!/bin/sh

if [ "$CSIRO_GIT_TOS" != "" ]; then
   : # already set, ignore
else
if [ "$BASH_ARGV" != "" -a `uname` == "Linux" ]; then
   # we are inside bash in linux
   echo $BASH_ARGV
   export CSIRO_GIT_TOS=$(dirname $(readlink -f $BASH_ARGV))
   echo "CSIRO_GIT_TOS=$CSIRO_GIT_TOS (proper)" >&2
else
   # not a bash. fallback
   export CSIRO_GIT_TOS=`pwd`
   echo "CSIRO_GIT_TOS=$CSIRO_GIT_TOS (guessed)" >&2
fi
fi


# set absolute path to the "tinyos-csiro" folder here
export TOSROOT_CSIRO=$CSIRO_GIT_TOS/tinyos-csiro

# this is to find all CSIRO related files
export TOSDIR_CSIRO=$TOSROOT_CSIRO/tos
export TOSMAKE_PATH=$TOSROOT_CSIRO/support/make
export PATH=$PATH:$TOSROOT_CSIRO/support/sdk/c/sf
export PYTHONPATH=$TOSROOT_CSIRO/support/sdk/python:$PYTHONPATH
