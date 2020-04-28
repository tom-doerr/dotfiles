#!/bin/bash

/usr/bin/keychain --quiet --quick $HOME/.ssh/id_ed25519

if [[ $HOST == "" ]]
then
    source $HOME/.keychain/$HOSTNAME-sh
elif [[ $HOSTNAME == "" ]]
then
    source $HOME/.keychain/$HOST-sh
#else
#    echo 'Error! Can not get hostname, both $HOST and $HOSTNAME are empty.' 1>&2
#    sleep 0.2
#    #exit 1
fi

export VISUAL=nvim
export EDITOR="$VISUAL"
