#!/bin/bash

private_key_1=$HOME/.ssh/id_ed25519 
private_key_2=$HOME/.ssh/id_rsa
if [[ -f $private_key_1 ]]
then
    /usr/bin/keychain --quiet --quick $private_key_1
fi

if [[ -f $private_key_2 ]]
then
    /usr/bin/keychain --quiet --quick $private_key_2
fi


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
export PYTHONBREAKPOINT=ipdb.set_trace
export PATH="$PATH":"$HOME"/.cargo/bin
export PATH="$PATH":"$HOME"/go/bin
