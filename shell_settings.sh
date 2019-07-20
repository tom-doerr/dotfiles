#!/bin/bash

/usr/bin/keychain $HOME/.ssh/id_rsa

if [[ $HOST == "" ]]
then
    source $HOME/.keychain/$HOSTNAME-sh
elif [[ $HOSTNAME == "" ]]
then
    source $HOME/.keychain/$HOST-sh
else
    echo 'Error! Can not get hostname, both $HOST and $HOSTNAME are empty.' 1>&2
    exit 1
fi
