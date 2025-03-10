#!/bin/bash

#private_key_1=$HOME/.ssh/id_ed25519 
#private_key_2=$HOME/.ssh/id_rsa
#if [[ -f $private_key_1 ]]
#then
    #/usr/bin/keychain --quiet --quick $private_key_1
#fi

#if [[ -f $private_key_2 ]]
#then
    #/usr/bin/keychain --quiet --quick $private_key_2
#fi


#if [[ $HOST == "" ]]
#then
    #source $HOME/.keychain/$HOSTNAME-sh
#elif [[ $HOSTNAME == "" ]]
#then
    #source $HOME/.keychain/$HOST-sh
##else
##    echo 'Error! Can not get hostname, both $HOST and $HOSTNAME are empty.' 1>&2
##    sleep 0.2
##    #exit 1
#fi




# We're using passwordless SSH keys, so no SSH agent setup is needed.
# Programs will directly use the key file when needed.
# If you need agent forwarding or other SSH agent features, uncomment the section below.

# Uncomment if you need SSH agent features:
# if command -v keychain >/dev/null 2>&1; then
#     eval $(keychain --quiet --agents ssh ~/.ssh/id_ed25519)
# else
#     if [ -z "$SSH_AUTH_SOCK" ]; then
#         eval "$(ssh-agent -s)" > /dev/null
#         ssh-add ~/.ssh/id_ed25519 2>/dev/null
#     fi
# fi

# Uncomment if using SSH agent:
# ssh-add -l | grep -q "$(ssh-keygen -lf ~/.ssh/id_ed25519.pub | awk '{print $2}')" || ssh-add ~/.ssh/id_ed25519 2>/dev/null

export VISUAL=nvim
export EDITOR="$VISUAL"
export PYTHONBREAKPOINT=ipdb.set_trace
export SPOTIFY_DBUS_CLIENT=spotifyd
export PATH="$PATH":"$HOME"/.cargo/bin
export PATH="$PATH":"$HOME"/go/bin
export PATH="$HOME/git/scripts_path:$PATH"
